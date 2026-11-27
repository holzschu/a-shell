# MultiMarkdown framework

`nice -n 15 bash scripts/build-multimarkdown.sh` builds the existing embedded command for iOS 14 with device arm64 and universal arm64/x86_64 Simulator slices. It uses MultiMarkdown 6.7.0 at `6b6155d5041a023d0de44adf182506c52202a03c`, its CMake static-library target, and the checksum-pinned public ios_system 3.0.5 framework. Outputs, checksums and the dynamic-artifact audit are under `.build/multimarkdown/dist`.

The app already registers `multimarkdown` and embeds it in full and mini. This recipe retains that native command and its CLI. The adapter routes standard streams and termination through ios_system; a source patch leaves borrowed stdin open. It does not change Markdown conversion algorithms. The upstream MIT and Revised BSD licenses are included in each framework.

The recipe first runs a Mac contract test through the original command entry point with the stream adapter. It repeats an output-file error followed by Unicode HTML conversion 20 times, checks captured stderr, exact output and borrowed stdin, and requires no descriptor growth. This host test supplies the external runtime symbols; it does not qualify ios_system execution on iOS.

To verify recovery from interrupted downloads, run `bash multimarkdown/test-download-cache.sh`. It builds in a temporary directory with both cached downloads truncated and checks the resulting ZIP's SHA-256.

The framework workflow uploads the ZIP, its SHA-256 and the audit report. It does not change app dependencies or publish a release.
