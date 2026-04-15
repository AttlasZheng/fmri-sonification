LiSa lisa => dac;

"samples/3/a/high/breathy.wav" => lisa.read;
53 => lisa.maxVoices;

for (int i; i < lisa.maxVoices(); i++) {
  (i, i) => lisa.pan;
}

fun void grain(LiSa @ lisa, float rate, dur pos, dur len, dur up, dur down) {
  lisa.getVoice() => int voice;

  if (voice > -1) {
    (voice, rate) => lisa.rate;
    (voice, pos) => lisa.playPos;
    (voice, up) => lisa.rampUp;

    (len - up) => now;

    (voice, down) => lisa.rampDown;

    down => now;
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
      spork ~ grain(lisa, 1, ((n => msg.getFloat, 0, 1, 0, lisa.duration() / samp) => Math.map)::samp, 100::ms, 5::ms, 5::ms);
    }
  }
}
