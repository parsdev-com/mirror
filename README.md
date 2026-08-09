# میرور لینوکس پارسدِو
#### mirror.parsdev.com

مخازن رسمی اوبونتو، دبیان، آلما لینوکس و Proxmox بر روی سرورهای پارسدِو میرور (Mirror) شده اند.<br/>
با تغییر مخزن سرور به این آدرس، دریافت بسته ها و بروزرسانی ها از شبکه داخلی و با سرعت بسیار بالاتر انجام می شود.<br/>
در ادامه ابتدا روش خودکار و سپس دستورات دستی هر توزیع آورده شده است. برای هر توزیع دستور بازگشت (Rollback) هم موجود است تا در هر زمان بتوانید مخازن اولیه را برگردانید.

## روش خودکار

اسکریپت زیر توزیع و نسخه سرور را خودش تشخیص می دهد و تمام مراحل بخش دستی را انجام می دهد. دستور را با کاربر root اجرا کنید.

```bash
curl -fsSL https://raw.githubusercontent.com/parsdev-com/mirror/main/setup.sh | bash
```

برای بازگرداندن مخازن اولیه:

```bash
curl -fsSL https://raw.githubusercontent.com/parsdev-com/mirror/main/setup.sh | bash -s -- --rollback
```

> **نکته**
>
> اگر با کاربر غیر root وارد شده اید و `sudo` روی سرور نصب است، از `| sudo bash` استفاده کنید.

## روش دستی

روی عنوان سیستم خود کلیک کنید تا دستورات آن باز شود.

### Ubuntu

<details>
  <summary>
  Ubuntu 22.04 LTS — jammy
  </summary>

فایل `/etc/apt/sources.list` بازنویسی می شود:

```bash
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list >/dev/null <<'EOF'
# ParsDev Mirror — Ubuntu 22.04
deb https://mirror.parsdev.com/ubuntu/ jammy main restricted universe multiverse
deb https://mirror.parsdev.com/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirror.parsdev.com/ubuntu/ jammy-security main restricted universe multiverse
deb https://mirror.parsdev.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF
sudo apt-get update
```

بازگشت:

```bash
sudo cp /etc/apt/sources.list.bak /etc/apt/sources.list
sudo apt-get update
```

> **نکته**
>
> بروزرسانی های امنیتی از همین درخت دریافت می شوند و هاست جداگانه ای برای security وجود ندارد.

</details>

<details>
  <summary>
  Ubuntu 20.04 LTS — focal
  </summary>

```bash
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list >/dev/null <<'EOF'
# ParsDev Mirror — Ubuntu 20.04
deb https://mirror.parsdev.com/ubuntu/ focal main restricted universe multiverse
deb https://mirror.parsdev.com/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirror.parsdev.com/ubuntu/ focal-security main restricted universe multiverse
deb https://mirror.parsdev.com/ubuntu/ focal-backports main restricted universe multiverse
EOF
sudo apt-get update
```

بازگشت:

```bash
sudo cp /etc/apt/sources.list.bak /etc/apt/sources.list
sudo apt-get update
```

</details>

### Debian

<details>
  <summary>
  Debian 13 — trixie
  </summary>

```bash
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list >/dev/null <<'EOF'
# ParsDev Mirror — Debian 13
deb https://mirror.parsdev.com/debian/debian-13/ trixie main contrib non-free non-free-firmware
deb https://mirror.parsdev.com/debian/debian-13/ trixie-updates main contrib non-free non-free-firmware
deb https://mirror.parsdev.com/debian/debian-13-security/ trixie-security main contrib non-free non-free-firmware
EOF
sudo apt-get update
```

بازگشت:

```bash
sudo cp /etc/apt/sources.list.bak /etc/apt/sources.list
sudo apt-get update
```

> **نکته**
>
> هر نسخه دبیان روی این میرور دایرکتوری جداگانه خود را دارد: مخزن اصلی در `/debian/debian-13/` و مخزن امنیتی در `/debian/debian-13-security/`. مسیر `/debian/` به تنهایی کار نمی کند. مخزن backports هم میرور نشده است.

</details>

<details>
  <summary>
  Debian 12 — bookworm
  </summary>

```bash
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list >/dev/null <<'EOF'
# ParsDev Mirror — Debian 12
deb https://mirror.parsdev.com/debian/debian-12/ bookworm main contrib non-free non-free-firmware
deb https://mirror.parsdev.com/debian/debian-12/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirror.parsdev.com/debian/debian-12-security/ bookworm-security main contrib non-free non-free-firmware
EOF
sudo apt-get update
```

بازگشت:

```bash
sudo cp /etc/apt/sources.list.bak /etc/apt/sources.list
sudo apt-get update
```

> **نکته**
>
> هر نسخه دبیان روی این میرور دایرکتوری جداگانه خود را دارد: مخزن اصلی در `/debian/debian-12/` و مخزن امنیتی در `/debian/debian-12-security/`. مسیر `/debian/` به تنهایی کار نمی کند. مخزن backports هم میرور نشده است.

</details>

<details>
  <summary>
  Debian 11 — bullseye
  </summary>

```bash
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list >/dev/null <<'EOF'
# ParsDev Mirror — Debian 11
deb https://mirror.parsdev.com/debian/debian-11/ bullseye main contrib non-free
deb https://mirror.parsdev.com/debian/debian-11/ bullseye-updates main contrib non-free
deb https://mirror.parsdev.com/debian/debian-11-security/ bullseye-security main contrib non-free
EOF
sudo apt-get update
```

بازگشت:

```bash
sudo cp /etc/apt/sources.list.bak /etc/apt/sources.list
sudo apt-get update
```

> **نکته**
>
> نسخه bullseye پیش از جدا شدن مؤلفه non-free-firmware منتشر شده و به همین دلیل این مؤلفه در دستور بالا نیامده است.<br/>
> مانند سایر نسخه ها، مخزن اصلی در `/debian/debian-11/` و مخزن امنیتی در `/debian/debian-11-security/` قرار دارد.

</details>

### AlmaLinux

<details>
  <summary>
  AlmaLinux 9 / 10
  </summary>

فایل های `/etc/yum.repos.d/almalinux*.repo` ویرایش می شوند:

```bash
sudo cp -a /etc/yum.repos.d /etc/yum.repos.d.bak
sudo sed -i -e 's|^mirrorlist=|#mirrorlist=|g' \
  -e 's|^#\?baseurl=https\?://repo\.almalinux\.org/almalinux|baseurl=https://mirror.parsdev.com/Almalinux|g' \
  /etc/yum.repos.d/almalinux*.repo
sudo dnf clean all && sudo dnf makecache
```

بازگشت:

```bash
sudo cp -a /etc/yum.repos.d.bak/. /etc/yum.repos.d/
sudo dnf clean all && sudo dnf makecache
```

> **توجه**
>
> مسیر مخزن `/Almalinux/` با حرف A بزرگ است؛ با املای کوچک، dnf خطای 404 می دهد.

</details>

<details>
  <summary>
  AlmaLinux 8
  </summary>

دستور با نسخه های ۹ و ۱۰ یکسان است؛ تنها فایل های پیش فرض مخزن تفاوت دارند.

```bash
sudo cp -a /etc/yum.repos.d /etc/yum.repos.d.bak
sudo sed -i -e 's|^mirrorlist=|#mirrorlist=|g' \
  -e 's|^#\?baseurl=https\?://repo\.almalinux\.org/almalinux|baseurl=https://mirror.parsdev.com/Almalinux|g' \
  /etc/yum.repos.d/almalinux*.repo
sudo dnf clean all && sudo dnf makecache
```

بازگشت:

```bash
sudo cp -a /etc/yum.repos.d.bak/. /etc/yum.repos.d/
sudo dnf clean all && sudo dnf makecache
```

</details>

### Proxmox

<details>
  <summary>
  Proxmox VE 9 — trixie
  </summary>

فایل `/etc/apt/sources.list.d/pve-no-subscription.list` ساخته می شود:

```bash
sudo cp -a /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
sudo sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/pve-enterprise.list 2>/dev/null
sudo tee /etc/apt/sources.list.d/pve-no-subscription.list >/dev/null <<'EOF'
# ParsDev Mirror — Proxmox VE 9
deb https://mirror.parsdev.com/proxmox/ trixie pve-no-subscription
EOF
sudo apt-get update
```

بازگشت:

```bash
sudo rm -f /etc/apt/sources.list.d/pve-no-subscription.list
sudo cp -a /etc/apt/sources.list.d.bak/. /etc/apt/sources.list.d/
sudo apt-get update
```

> **نکته**
>
> مخازن دبیانِ زیرِ سیستم را هم به میرور تغییر دهید — بخش Debian 13 در بالا.

</details>

<details>
  <summary>
  Proxmox VE 8 — bookworm
  </summary>

```bash
sudo cp -a /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
sudo sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/pve-enterprise.list 2>/dev/null
sudo tee /etc/apt/sources.list.d/pve-no-subscription.list >/dev/null <<'EOF'
# ParsDev Mirror — Proxmox VE 8
deb https://mirror.parsdev.com/proxmox/ bookworm pve-no-subscription
EOF
sudo apt-get update
```

بازگشت:

```bash
sudo rm -f /etc/apt/sources.list.d/pve-no-subscription.list
sudo cp -a /etc/apt/sources.list.d.bak/. /etc/apt/sources.list.d/
sudo apt-get update
```

> **نکته**
>
> مخازن دبیانِ زیرِ سیستم را هم به میرور تغییر دهید — بخش Debian 12 در بالا.

</details>

<details>
  <summary>
  Proxmox Backup Server
  </summary>

فایل `/etc/apt/sources.list.d/pbs-no-subscription.list` ساخته می شود:

```bash
sudo cp -a /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
sudo sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/pbs-enterprise.list 2>/dev/null
sudo tee /etc/apt/sources.list.d/pbs-no-subscription.list >/dev/null <<'EOF'
# ParsDev Mirror — Proxmox Backup Server
deb https://mirror.parsdev.com/proxmox/pbs/ bookworm pbs-no-subscription
EOF
sudo apt-get update
```

بازگشت:

```bash
sudo rm -f /etc/apt/sources.list.d/pbs-no-subscription.list
sudo cp -a /etc/apt/sources.list.d.bak/. /etc/apt/sources.list.d/
sudo apt-get update
```

> **نکته**
>
> اگر Backup Server شما روی دبیان ۱۳ اجرا می شود، عبارت bookworm را به trixie تغییر دهید.

</details>

## توزیع های میرور شده

Ubuntu focal و jammy · Debian bullseye و bookworm و trixie · AlmaLinux 8 و 9 و 10 · Proxmox VE و Backup Server.<br/>
Ubuntu و Debian تنها برای معماری amd64 میرور شده اند.<br/>
فهرست کامل مخازن از طریق [mirror.parsdev.com](https://mirror.parsdev.com/) قابل مرور است.
