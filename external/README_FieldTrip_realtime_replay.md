# FieldTrip Realtime Replay Workflow

This workflow tests the existing `live_fieldtrip` consumer program against a
local FieldTrip realtime buffer fed from a recorded dataset. The producer is
only a local development utility; it is not part of the MEG-room program.

## Session A - Producer

Run this in a separate MATLAB session. It remains occupied while
`ft_realtime_fileproxy` is replaying the file.

```matlab
startup;

datasetPath = 'C:\path\to\recording.ds';

[RTConfig, ReplayConfig] = nf_local_fieldtrip_replay_config(datasetPath);

ReplayResult = nf_start_fieldtrip_file_replay(ReplayConfig);
```

## Session B - Consumer

Run the normal live FieldTrip checks against the local replay endpoint.

```matlab
startup;

datasetPath = 'C:\path\to\recording.ds';

[RTConfig, ReplayConfig] = nf_local_fieldtrip_replay_config(datasetPath);

ChannelResult = nf_run_live_channel_check(RTConfig);
SmokeResult   = nf_run_live_chunk_smoke_test(RTConfig);
DryRunResult  = nf_run_live_rt_dry_run(RTConfig);
```

After those pass, run the existing full self-test with the intended spatial and
feedback configuration:

```matlab
SelfTestResult = nf_run_live_self_test(RTConfig);
```

## Transport-Only Fallback Example

This mode is useful for endpoint and timing checks only. It does not prove IPS
neurofeedback.

```matlab
Modes = nf_modes();
[RTConfig, ReplayConfig] = nf_local_fieldtrip_replay_config(datasetPath);

RTConfig.Spatial.MatrixSource = Modes.Spatial.MatrixSource.TechnicalFallback;

RTConfig.Source.CTF.ApplyChannelGains = false;
RTConfig.Source.CTF.ApplyMegRefCorrection = false;
RTConfig.Source.CTF.ApplyProjector = false;
```

Reports must continue to show `IsIPS = false` and
`IsTechnicalFallback = true`.

## MEG-Room Transition

The downstream consumer remains the same `live_fieldtrip` program. For the MEG
room, change the endpoint to the confirmed live acquisition buffer:

```matlab
RTConfig.Source.FieldTrip.Host = '10.68.1.239';
RTConfig.Source.FieldTrip.Port = <confirmed port>;
RTConfig.Source.FieldTrip.StreamRole = 'live_meg';
```

Do not assume only `Host` changes if the confirmed port, CTF metadata profile,
or spatial matrix metadata differs. The producer session above is not used in
the MEG room.
