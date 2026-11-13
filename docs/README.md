# دەمەتەقێ documentation

Start with the project [README](../README.md) for what the app is, how to install it and what has and has
not been verified. These documents go deeper.

| Document | What it answers |
| --- | --- |
| [feature-status.md](feature-status.md) | **What is implemented, partial or deferred**, the deviations from the specification, and the known limitations. Read this first |
| [architecture.md](architecture.md) | Layers, the module structure, how a message travels, state and storage, testing seams |
| [database.md](database.md) | Relationship diagram, schema, constraints and indexes, migrations, retention rules, mapping to the specification's table names |
| [protocol.md](protocol.md) | The Bluetooth mesh protocol: link frames, packet format, envelopes, media chunks, control events, limits |
| [delivery-and-routing.md](delivery-and-routing.md) | Message states and what they mean, routing, relaying (and opting out), clocks, background behavior of Android and iOS |
| [security.md](security.md) | Threat model, cryptography, who may delete or edit what, notification privacy, local data, limitations |
| [testing.md](testing.md) | The specification's 24 test areas mapped to automated tests, and what the simulation cannot show |
| [real-device-test-plan.md](real-device-test-plan.md) | How to test on physical phones, what to record. **Not yet done** |
| [voice-calls-design.md](voice-calls-design.md) | Feasibility and design of offline voice calls. **Design only** |
| [localization.md](localization.md) | The three languages (Kurdish is the main one, Arabic, English), right-to-left layouts, how to add a message or a language, what is and is not verified |
| [ui-design.md](ui-design.md) | The interface after the October 2026 redesign: the public room first, the floating bar, colour and type, the light and dark appearances and how to change them, Kurdish and Arabic typography, the Settings menu, what was checked and what was not |
| [build-and-debug.md](build-and-debug.md) | Build commands, running on phones, permissions and platform configuration, troubleshooting |

Two rules run through all of them: a feature is only called working when it is implemented **and** tested,
and everything that was only tested in simulation says so.
