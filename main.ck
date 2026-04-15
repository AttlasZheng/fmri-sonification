53 => int N;

SndBuf bufs[N];
ADSR envs[N];
int playing[N];
int current[N][6];

for (int i; i < N; i++) bufs[i] => envs[i] => (i => dac.chan);

// "" => read;

fun void read(string name) {
  for (int i; i < N; i++) name => bufs[i].read;
}

fun void grain(float rate, int pos, dur len, dur up, dur down) {
  -1 => int voice;
  for (int i; i < N; i++) if (!playing[i]) { i => voice; break; }

  if (voice > -1) {
    true => playing[voice];

    rate => bufs[voice].rate;
    pos => bufs[voice].pos;

    (up, 0::ms, 1, down) => envs[voice].set;
    envs[voice].keyOn();

    (len - up) => now;

    envs[voice].keyOff();

    down => now;

    false => playing[voice];
  }
}

OscIn oin;

6667 => oin.port;

cherr <= "listening for OSC messages over port: " <= oin.port()
      <= "..." <= IO.newline();

oin.listenAll();

OscMsg msg;

while (true) {
  (1. / 60.)::second => now;

  while (msg => oin.recv) {
    if (msg.address != "/row") continue;
    // for (int n; n < msg.numArgs(); n++) {
    for (int n; n < N; n++) {
      true => current[n][0];
      1 => current[n][1];
      ((n => msg.getFloat, 0, 1, 0, bufs[0].samples()) => Math.map) $ int => current[n][2];
      100 => current[n][3];
      5 => current[n][4];
      5 => current[n][5];

      spork ~ grain(current[n][0], current[n][1], 100::ms, 5::ms, 5::ms);
    }
  }

  for (int i; i < N; i++) {
    if (current[i][0]) spork ~ grain(current[i][1], current[i][2], current[i][3]::ms, current[i][4]::ms, current[i][5]::ms);
  }
}
