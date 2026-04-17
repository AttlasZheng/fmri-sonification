
[
    "audio 1/a/high/raspy a high.wav",
    "audio 1/a/high/breathy a high.wav",
    "audio 1/a/high/supported a high.wav",
    "audio 1/a/mid/raspy a mid.wav",
    "audio 1/a/mid/breathy a mid.wav",
    "audio 1/a/mid/supported a mid.wav",
    "audio 1/a/low/Raspy a low.wav",
    "audio 1/a/low/breathy a low.wav",
    "audio 1/a/low/Supported a low.wav"
] @=> string sampleFiles[];

0 => int sampleIndex;
sampleFiles[sampleIndex] => string filename;

// OSC port
8000 => int OSC_PORT;

// grain settings
53 => int NUM_GRAINS;
25::ms => dur grainDur;
4.0::ms => dur grainAttack;
50::ms => dur grainInterval;

float grainVolumes[NUM_GRAINS];
for (0 => int i; i < NUM_GRAINS; i++)
{
    0.3 => grainVolumes[i];
}

0 => int totalSamples;
0 => int grainSamples;
0 => int maxStartSample;

0 => int sampleVersion;


// =========================
// helper: clamp float
// =========================

fun float clamp01(float x)
{
    if (x < 0.0) return Math.min(-x, 1.0);
    if (x > 1.0) return 1.0;
    return x;
}


fun void refreshSampleState()
{
    SndBuf temp => blackhole;

    sampleFiles[sampleIndex] => filename;
    filename => temp.read;

    temp.samples() => totalSamples;

    if (totalSamples <= 0)
    {
        <<< "ERROR: could not load file:", filename >>>;
        return;
    }

    (grainDur / samp) $ int => grainSamples;
    totalSamples - grainSamples => maxStartSample;

    if (maxStartSample < 0)
    {
        <<< "ERROR: file shorter than one grain:", filename >>>;
        0 => maxStartSample;
    }

    sampleVersion++;

    <<< "Loaded file:", filename >>>;
    <<< "Sample index:", sampleIndex >>>;
    <<< "Total samples:", totalSamples >>>;
    <<< "Actual sample rate:", second / samp >>>;
    <<< "maxStartSample:", maxStartSample >>>;
    <<< "sampleVersion:", sampleVersion >>>;
}


refreshSampleState();

if (totalSamples <= 0)
{
    me.exit();
}

<<< "OSC port:", OSC_PORT >>>;


// =========================
// OSC receiver
// =========================

OscRecv recv;
OSC_PORT => recv.port;
recv.listen();


// =========================
// OSC listener for one volume
// =========================

fun void volumeListener(int index)
{
    OscEvent oe;
    recv.event("/controller" + index + ", f") @=> oe;

    while (true)
    {
        oe => now;

        while (oe.nextMsg() != 0)
        {
            clamp01(oe.getFloat()) => grainVolumes[index];
        }
    }
}


// =========================
// OSC listener for interval
// unit: milliseconds
// e.g. send 20.0 means 20 ms
// =========================

fun void intervalListener()
{
    OscEvent oe;
    recv.event("/controller/yoke, f") @=> oe;

    while (true)
    {
        oe => now;

        while (oe.nextMsg() != 0)
        {
            oe.getFloat() => float intervalMs;

            intervalMs * 100 => intervalMs;

            if (intervalMs < 5.0) 5.0 => intervalMs;

            intervalMs::ms => grainInterval;
        }
    }
}


// =========================
// OSC listener for attack
// =========================

fun void attackListener()
{
    OscEvent oe;
    recv.event("/controller/throttle1, f") @=> oe;

    while (true)
    {
        oe => now;

        while (oe.nextMsg() != 0)
        {
            oe.getFloat() => float attackMs;

            if (attackMs < 1.0) 1.0 => attackMs;
            if (attackMs > 20.0) 20.0 => attackMs;

            attackMs::ms => grainAttack;

            <<< "Updated attack =", attackMs, "ms" >>>;
        }
    }
}


// =========================
// OSC listener for sample index
// =========================

fun void sampleIndexListener()
{
    OscEvent oe;
    recv.event("/controller/throttle2, f") @=> oe;

    while (true)
    {
        oe => now;

        while (oe.nextMsg() != 0)
        {
            oe.getFloat() => float thisIndex;

            Math.floor(thisIndex * sampleFiles.size()) $ int => int newIndex;

            if (newIndex < 0) 0 => newIndex;
            if (newIndex >= sampleFiles.size()) sampleFiles.size() - 1 => newIndex;

            if (newIndex != sampleIndex)
            {
                newIndex => sampleIndex;
                refreshSampleState();
                <<< "Updated sample =", sampleIndex >>>;
            }
        }
    }
}


// =========================
// one looping grain voice
// each voice owns:
//   - its own SndBuf
//   - its own ADSR
// =========================

fun void grainVoice(int index)
{
    SndBuf g => ADSR env => dac;

    -1 => int localSampleIndex;
    -1 => int localSampleVersion;

    5::ms => dur decay;
    0.8 => float sustainLevel;
    5::ms => dur release;

    (index * 2)::ms => now;

    while (true)
    {
        if (localSampleVersion != sampleVersion || localSampleIndex != sampleIndex)
        {
            sampleFiles[sampleIndex] => g.read;
            sampleIndex => localSampleIndex;
            sampleVersion => localSampleVersion;

            if (g.samples() <= 0)
            {
                <<< "ERROR: failed to load sample", sampleIndex >>>;
                100::ms => now;
                continue;
            }
        }

        clamp01(grainVolumes[index]) => g.gain;

        if (g.samples() > 0)
        {
            Math.random2(0, g.samples() - 1) => g.pos;
        }

        grainAttack => dur attack;

        if (grainDur < attack + decay + release)
        {
            1::ms => attack;
            1::ms => decay;
            1::ms => release;
        }

        env.set(attack, decay, sustainLevel, release);

        env.keyOn();
        grainDur - release => now;
        env.keyOff();
        release => now;

        grainInterval => now;
    }
}


// =========================
// start OSC listeners
// =========================

for (0 => int i; i < NUM_GRAINS; i++)
{
    spork ~ volumeListener(i);
}

spork ~ intervalListener();
spork ~ attackListener();
spork ~ sampleIndexListener();


// =========================
// start 53 looping grain voices
// =========================

for (0 => int i; i < NUM_GRAINS; i++)
{
    spork ~ grainVoice(i);
}


// =========================
// keep VM alive forever
// =========================

while (true)
{
    1::second => now;
}