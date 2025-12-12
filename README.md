# SparseBox

On-device backup restoration?

- [x] rewrote SparseRestore to swift

> [!NOTE]
> I have no interest in updating this project at the moment, see Releases for more info. PR welcome.

## Installation
SideStore is recommended as you will also be getting the pairing file and setting up VPN.

Download ipa from [Releases](https://github.com/khanhduytran0/SparseBox/releases), Actions tab or [nightly.link](https://nightly.link/khanhduytran0/SparseBox/workflows/build/main/artifact.zip)

Before opening SparseBox, you have to close SideStore from app switcher. This is because only one app can use VPN proxy at a time. Maybe changing port could solve this issue.

## Thanks to
- @SideStore team: idevice, C bindings from StikDebug
- @JJTech0130: SparseRestore and backup exploit
- @hanakim3945: bl_sbx exploit files and writeup
- @PoomSmart: MobileGestalt dump
- @Lakr233: BBackupp
- @libimobiledevice
- [the sneakyf1shy apple intelligence tutorial](https://gist.github.com/f1shy-dev/23b4a78dc283edd30ae2b2e6429129b5#file-best_sae_trick-md)
