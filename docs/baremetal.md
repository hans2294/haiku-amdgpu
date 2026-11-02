# Haiku direkte på maskinen (uden VM)

Samme image som i VM'en, med driveren, Mesa og Vulkan som pakker. Det
starter fra en USB-nøgle via UEFI, så maskinens diske ikke røres.

## Maskinen

| Enhed | Haiku |
|---|---|
| RX 7900 GRE (03:00.0, 1002:744c) | vores amdgpu (Linux 6.12 på linuxkpi) |
| Raphael iGPU (1b:00.0, 1002:164e) | **ignoreres**: driveren tager kun enheder på sin liste |
| GTX 1660 SUPER (04:00.0) | ingen driver; højst EFI-framebufferen, hvis firmwaren viser boot der |
| NVMe (MAXIO, Intel 600P), SATA | nvme/ahci; Linux-partitionerne monteres ikke automatisk |
| RTL8125 2.5GbE | `rtl8125` (DHCP, sshd kører) |
| MT7925 Wi-Fi | ingen driver |
| USB (AMD xHCI) | tastatur og mus |

Firmwaren kører UEFI med Secure Boot slået fra, og Resizable BAR er slået
til. 7900 GRE'ens BAR på 16 GiB er den samme som i VM'en.

## Før

1. **En skærm på 7900 GRE'en** (DP eller HDMI). Skrivebordet kommer på den
   første tilsluttede udgang. Capture-donglen hjælper ikke her, for den sidder
   i den maskine, der nu kører Haiku.
2. **En USB-nøgle på mindst 4,2 GB.** Alt på den overskrives.

## Image og nøgle

Find nøglen (TRAN = usb) og dens størrelse i bytes:

```bash
lsblk -bo NAME,SIZE,TRAN,MODEL
```

Byg et image, der fylder hele nøglen, og skriv det:

```bash
vm/usb-image.sh <størrelse i bytes>
```

```bash
sudo vm/write-usb.sh /dev/sdX
```

`vm/usb-image.sh` laver `generated.x86_64/haiku-navi-usb.img`: en MBR, en
EFI-partition og en BFS-partition med resten af nøglen. Et anyboot-image kan
højst være 4 GB, så det er en anden slags image end VM'ens. Det har ingen
boot-tests, og det har kun HaikuPorts som pakkekilde.

`vm/write-usb.sh` nægter at skrive, hvis enheden ikke er en hel, umonteret
USB-disk, der er stor nok. Du skal også skrive enhedsnavnet igen for at
bekræfte. Den skriver kun de blokke, BFS bruger (ca. 420 MiB, ikke 29 GB), og
læser dem tilbage til kontrol. **Alt på nøglen går tabt.**

`vm/baremetal-image.sh` laver stadig et anyboot-image på 4 GB, med testene.

### På en intern disk

Samme image kan skrives til en SATA-disk eller SSD. Den vælges med sit
serienummer, for bogstaverne (`sdc`, `sdd`) flytter sig, og maskinens andre diske
holder rigtige data (`lsblk -o NAME,SIZE,MODEL,SERIAL`):

```bash
vm/usb-image.sh 120000000000
```

```bash
sudo vm/write-disk.sh <serienummer>
```

Et image på 120 GB passer på både en 128 GB-SSD og større diske; resten af en
større disk står ubrugt. Skrivningen fjerner også reservekopien af en gammel GPT i
slutningen af disken, som Haiku ellers kunne læse de gamle partitioner fra.

## Installere programmer

- `pkgman install <pakke>` og HaikuDepot virker, og `pkgman update` holder
  sig fra vores pakker.
- **Brug ikke `pkgman full-sync`.** Den fjerner `mesa_radeon`, installerer
  Mesa 22 igen og skifter Vulkan-loaderen ud, så GL og Vulkan holder op med at
  virke på kortet.
- Den officielle `Haiku`-pakkekilde er med vilje ikke med, for en opdatering
  derfra ville erstatte vores app_server og libgame. Et program, der kræver en
  nyere haiku-pakke, kan derfor ikke installeres; pkgman melder det som et
  problem i stedet for at skifte haiku ud.
- Haiku laver selv en swap-fil, op til en fjerdedel af den ledige plads
  (omkring 7 GB her). Den kan slås fra i *VirtualMemory* i Preferences.

## Opdatere enkelte filer

Et nyt image sletter det, der er installeret på nøglen. En enkelt fil kan
lægges på uden at røre resten, og filen i `non-packaged` går forud for den fra
pakkerne:

```bash
sudo vm/update-stick.sh /dev/sdX <fil> <mappe under non-packaged>
```

Fjern filen på nøglen for at gå tilbage til den fra pakken.

## Boot

1. Genstart, og åbn firmwarens boot-menu (typisk F8, F11 eller F12), og vælg
   **UEFI: \<nøglen\>**.
2. Haiku starter. Boot-skærmen vises på den GPU, firmwaren viser på.
   Derefter kommer skrivebordet på 7900 GRE'ens skærm.
3. Der kører ingen tests ved opstart. De findes stadig som kommandoer
   (`amdgputest`, `gltest`, `vkwindow`, `vsynctest`, `tearingtest`).
   Fejl og driverens log står i `/var/log/syslog`.

**Hvis det hænger eller går i KDL:** tag et billede af skærmen. Sluk derefter
**helt** (strømmen af, ikke bare reset), for kortets PSP-tilstand overlever
en varm genstart. For at starte uden driveren: hold Shift (eller Space)
under boot, vælg *Select safe mode options* → *Disable system components*,
og bloker `add-ons/kernel/drivers/bin/amdgpu`.

## Tilbage i Linux

Boot fra Linux-disken som normalt, og sæt nøglen i:

```bash
sudo vm/read-usb-report.sh /dev/sdX
```

Det monterer nøglens BFS-partition skrivebeskyttet (Linux' `befs`) og
kopierer `syslog` og `previous_syslog` (og en evt. testrapport) til
`logs/baremetal/<tid>/`.

## Andre GPU'er

Driveren tager kun Navi 31 (744c). Settings-filen
`/boot/home/config/settings/kernel/drivers/amdgpu` kan ændre det:

    devices 744c 164e

eller `devices all`. Uden en tilladt enhed indlæses driveren slet ikke, og
skrivebordet går til framebufferen (afprøvet i VM'en med `devices 164e`).

## Første kørsel (2026-11-01)

Det virkede på første forsøg, fra USB på maskinen selv, med begge skærme på
7900 GRE'en (én ad gangen; driveren bruger den første tilsluttede udgang):

| | HDMI, 3840x1080 @ 60 Hz | DP, 5120x1440 @ 240 Hz |
|---|---|---|
| `WaitForRetrace` | 59,94 Hz | 239,75 Hz |
| `SwapBuffers(true)` | 60,1 fps | 238,4 fps |
| GL, bitmap / direkte | 8.782 / 17.633 fps | 8.700 / 16.265 fps |
| Vulkan direkte, IMMEDIATE | 5.067 fps | 5.500 fps |
| Vulkan direkte, FIFO | 60,2 fps | 239,9 fps |
| Vulkan gennem viewet | 2.329 fps | 2.307 fps |

Alle boot-tests bestod. Raphael-iGPU'en blev ladt i fred (`not probing amdgpu:
1002:164e is not on the device list`), og RTL8125 fik en adresse med DHCP.
Loggene ligger i `logs/baremetal/first-run/`.

Fejlen fra kørslen, GL der sad fast på den gamle plads, når GLTeapot blev
flyttet, er beskrevet i [amdgpu-port.md](amdgpu-port.md) og rettet; rettelsen
mangler at blive prøvet på maskinen selv.

## Frysninger

**Årsag fundet (2026-11-01): en kernepanik, ikke en frysning.** I VM'en, med 8 CPU'er,
16 GiB RAM, Luanti og Firefox (`vm/big-vm.sh`, `vm/stress.sh`, `vm/hangwatch.sh`), gik
kernen i KDL med Luanti i et `memcpy` til en vertex-buffer:

    PANIC: ASSERT FAILED (X86VMTranslationMap64Bit.cpp:254): (*entry & (1LL << 0)) == 0;
    virtual address: 0x1b5e41ff000, existing pte: 0x80000013f8c200e5

Driverens mappings til programmer var private områder. Et `fork()` gør private områder
copy-on-write: siderne bliver skrivebeskyttede, og næste skrivning giver et page fault.
Haiku lægger så en ny side ind i stedet, og for VRAM, der ikke er almindelig RAM, opdager
den ikke den gamle og går i panik. For RAM (GTT) kom der enten en panik ved oprydningen
eller en stille kopi, som GPU'en aldrig så. En mapping er nu `B_SHARED_AREA`, som en delt
mapping på Linux, og `libdrmtest` har en fork-test, der gav panik før og består nu.

På maskinen selv ligner en panik en total frysning: KDL tegner ikke på 7900 GRE'ens
skærm, så billedet står stille, og hverken mus eller Caps Lock reagerer. Selve paniken er kun set i VM'en, men med
rettelsen holdt maskinen til flere Firefox-vinduer og en halv times Luanti, hvor den før
frøs efter få minutter (2026-11-01).

Rettelsen lægges på en installeret disk uden at slette noget:

```bash
sudo vm/update-package.sh <serienummer> generated.x86_64/packages/amdgpu_linux-*.hpkg
```

Fryser den igen, så brug reset og *Save syslog from previous session*: hold Shift under
opstarten, vælg *Select debug options* → *Save syslog from previous session* → `HAIKU ESP`,
og sluk helt. Filen hedder `SYSLOGnn.TXT` på EFI-partitionen.


## På en almindelig Haiku

Pakkerne i `generated.x86_64/packages` installeres med `pkgman install` på en officiel
nightly, uden vores image. De fjerner selv `mesa`, `mesa_devel` og `mesa_swpipe`.
Skrivebordet kører da uden tearing-rettelsen, for den ligger i app_server.

Afprøvet i VM'en (2026-11-01), på anyboot-images af officielle nightlies med
`vm/nightly-vm.sh`, med en skærm på kortet ved 1280x720 og 60 Hz:

| Nightly | Dato | Resultat |
|---|---|---|
| hrev60317 | 2026-11-01 | Alt består |
| hrev60102 | 2026-09-14 | Alt består |
| hrev60028 | 2026-08-25 | Panik ved første fork (`VMCache::Commit`), rettet i kernen i hrev60102 |
| hrev59998 | 2026-08-20 | Panik ved opstart: statiske mutexes skiftede ABI i hrev60013 |
| hrev59601 | 2026-04-09 | Samme panik ved opstart |

Driveren nægter derfor at starte før hrev60102 (`amdgpu: not loading`), og skrivebordet
går til framebufferen. Det er prøvet på hrev59998. Pakken kan ikke selv sige fra: `pkgman`
installerer den alligevel, for `haiku` regnes for kompatibel helt tilbage til R1~alpha.
Efter sådan en installation virker GL ikke, for `mesa_radeon` har erstattet systemets Mesa.

Stabile udgaver er ikke prøvet. r1beta6 er forgrenet før hrev60102 og bør blive afvist af
samme tjek; den har `KDEBUG_LEVEL 1` mod nightlies' 2, så den skal have sin egen build.
Nyere kerner kan ikke tjekkes på forhånd, så en senere ændring af kernens private
strukturer kan stadig give panik.

Ikke prøvet på almindelig Haiku: Haikus Installer, en rigtig maskine og 240 Hz.

## Lyd gennem kortet (HDMI/DP)

Haikus `hda` springer digitale udgange over, så kortets lydenhed gav `no active codec`.
En rettelse i `hda` slår dem til, men kun for Navi 31's lydenhed (1002:ab30). Haiku slog
det til for alle i hrev59825 og rullede det tilbage, fordi analoge lydkort mistede deres
indstillinger (#20171). Den skriver også `DIGEN` i converter-kontrollen i stedet for
formatet.

Afprøvet i VM'en (2026-11-01): toner fra MediaPlayer lød på skærmens AUX-udgang over DP
ved 1280x720. Stereo, 48 kHz, 16 bit. Ikke prøvet: HDMI, maskinen selv, hvor der er flere
lydenheder at vælge imellem, og flere kanaler. AMD's egne indstillinger for kanaler og
infoframes bruges ikke, og det var ikke nødvendigt for stereo.

Haikus egen `hda` vinder over den i `non-packaged`, så den skal blokeres i
`/boot/system/settings/packages`:

    Package haiku {
    	BlockedEntries {
    		add-ons/kernel/drivers/dev/audio/hmulti/hda
    		add-ons/kernel/drivers/bin/hda
    	}
    }

Den rettede fil lægges i `non-packaged/add-ons/kernel/drivers/bin/hda`, med et link fra
`non-packaged/add-ons/kernel/drivers/dev/audio/hmulti/hda` til `../../../bin/hda`. I et
fuldt image er rettelsen med i Haikus egen pakke, hvis den er bygget ind.

## Den interne GPU (Raphael, 1002:164e)

Med `devices 164e` i driverens settings-fil (`sudo vm/try-igpu.sh <serienummer>`, fortrydes
med `off`) kører driveren den interne GPU i stedet for 7900 GRE'en, med skærmen i bundkortet.
Det er RDNA2 (GC 10.3.6, DCN 3.1.5) med 512 MiB VRAM.

Den krævede to ting: firmwaren (12 filer, i pakken) og VBIOS'en, som på en APU ligger i
ACPI-tabellen `VFCT`. ACPICA er ikke med i porten, så `pci_map_rom()` finder den via Haikus
ACPI-modul.

Afprøvet på maskinen selv (2026-11-02): skrivebordet kom op uden tearing, GLTeapot virkede,
og Luanti og Firefox kørte en tid uden fejl. Det er kun brugerens indtryk: loggene er ikke
læst, så det er ikke vist, hvor VBIOS'en kom fra, eller om buffere faktisk blev flyttet.
Accelerantet bruger kun det første kort, så Haiku bruger ikke begge GPU'er på én gang.

## Uden tearing på en almindelig Haiku

Haikus egen `app_server` tegner direkte i framebufferen og ved intet om page flip. Accelerantet
giver den derfor en skyggebuffer i RAM som framebuffer, og en tråd lægger de ændrede sider over i
den skjulte halvdel af en dobbelt buffer og flipper ved vblank. Driveren finder de ændrede sider
med sidetabellens dirty-bits (`LINUXKPI_IOCTL_DIRTY_PAGES`), også i klonede områder. Tråden venter
på, at skrivningerne holder pause, op til en halv opdatering, for `app_server` siger ikke, hvornår
den er færdig. `TEAR_FREE=0` slår det fra. Beder `app_server` selv om en dobbelt høj skærm, som
vores udgave gør, bruges skyggen ikke.

GL og Vulkan tegner ikke direkte i framebufferen, når der er en skygge, for kopien ville male
hen over dem, og går gennem bitmap-vejen (`LINUXKPI_IOCTL_GET_SCREEN_SHADOW`).

Målt med capture-donglen (`vm/capture.sh`, som skal køre, før VM'en starter, for donglen melder
sig først, når nogen læser fra den): et vindue på 800x600, der skifter mellem sort og hvidt, 451
billeder over 15 sekunder, 1920x1080 ved 60 Hz, officiel hrev60317, med skyggen også hrev60102
(2026-11-02). Knækkede billeder:

| Tempo | Uden skygge | Med skygge |
|---|---|---|
| Uden pause | 451 | 26 til 92 |
| 120 skift/s | ikke målt | 2 |
| 60 skift/s | 165 | 1 |
| 30 skift/s | 76 | 0 |
| 10 skift/s | 32 | 0 |

Et program, der tegner uden pause, kan stadig knække billeder. Ikke målt: 5120x1440 ved 240 Hz og
maskinen selv.

