53 => int N;

SndBuf bufs[N];
ADSR envs[N];
int playing[N];

for (int i; i < N; i++) bufs[i] => envs[i] => (i => dac.chan);

"/Users/tristanpeng/Desktop/soni-test/samples/3/a/high/breathy.wav" => read;

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

6449 => oin.port;

cherr <= "listening for OSC messages over port: " <= oin.port()
      <= "..." <= IO.newline();

oin.listenAll();

OscMsg msg;

while (true) {
  oin => now;

  while (oin.recv(msg)) {
    if (msg.address != "/test") continue;
    for (int n; n < msg.numArgs(); n++) {
      spork ~ grain(1, ((n => msg.getFloat, 0, 1, 0, bufs[0].samples()) => Math.map) $ int, 100::ms, 5::ms, 5::ms);
    }
  }
}
