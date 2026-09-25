# PLF110 Earpiece/Speaker Stereo v2.1.0

[English](README.md) | [简体中文](README.zh-CN.md) | Bahasa Indonesia

Modul KernelSU/Magisk ini ditujukan untuk OnePlus PLF110 Android 16 yang telah di-root.

Modul menetapkan `AUDIO_DEVICE_OUT_SPEAKER` dan `AUDIO_DEVICE_OUT_EARPIECE` ke strategi media 5, menjaga indeks media earpiece tetap mengikuti tombol volume media, dan mengatur amplifier pintar AW88265 agar memilih kanal I2S kanan. Earpiece tetap memakai jalur handset mono bawaan. Nada uji yang disertakan memeriksa apakah firmware mengirim kanal kiri saja ke jalur tersebut atau mencampur kedua kanal menjadi mono. Ini adalah pengujian pemisahan kanal, bukan efek surround virtual.

Pasang berkas ZIP melalui KernelSU atau Magisk, lalu mulai ulang perangkat. Tombol aksi modul dapat mengaktifkan atau menonaktifkan rute speaker ganda tanpa perlu memulai ulang. Saat modul dihapus, rute tersebut dibersihkan dan indeks perangkat earpiece yang disimpan pada pemasangan pertama akan dipulihkan.

Pemilihan kanal AW88265 memakai field `CHSEL` yang ditentukan driver pada register `I2SCTRL1 (0x06)` (Left=`1`, Right=`2`). Modul menyimpan nilai awal, menerapkan kanal kanan selama aktif, lalu memulihkannya ketika dinonaktifkan atau dihapus. Kernel, Audio HAL, dan tabel gain vendor tidak diubah.

Smart amplifier AW882xx pada speaker bawah tetap diredam secara terpisah melalui kontrol mixer `aw_dev_0_volume`. Nilai bawaannya `96`, setara dengan -12 dB (langkah 0,125 dB; `0` adalah pengaturan paling keras). Proses pemantau menerapkan ulang nilai ini setelah jalur audio dimulai ulang. Earpiece memakai indeks aman maksimum dari kontrol vendor `Handset Volume`, yaitu `0`; kontrol ini juga digunakan bersama oleh panggilan dan pesan suara, sehingga jalur tersebut dapat ikut lebih keras. Nilai mixer valid yang tersimpan dipulihkan saat modul dinonaktifkan atau dihapus.

Perubahan tabel gain tetap dinonaktifkan karena HAL MediaTek mengalami crash saat memuat ulang tabel yang diubah. Modul mempertahankan tabel gain bawaan.

Putar `左右声道测试.wav` pada volume media rendah. Nada 440 Hz pertama adalah kanal kiri; nada 880 Hz berikutnya adalah kanal kanan. Untuk keluaran terpisah, nada pertama seharusnya hanya terdengar dari earpiece dan nada kedua dari speaker bawah. Jika earpiece juga memainkan nada kedua, rute HAL sedang mencampur stereo menjadi mono dan memerlukan perubahan HAL/kebijakan terpisah.

Untuk menyetel media saja, tulis offset numerik ke `/data/adb/plf110_earpiece_dual_speaker/earpiece_offset`, lalu tekan tombol aksi modul; offset bawaan adalah 160 langkah volume media.

Untuk menyetel keseimbangan kenyaringan kiri/kanan tanpa membangun ulang modul, tulis bilangan bulat dari `0` hingga `720` ke `/data/adb/plf110_earpiece_dual_speaker/smartpa_attenuation`. Setiap langkah hanya menurunkan speaker bawah sebesar 0,125 dB; contohnya, `24` adalah -3 dB, `32` adalah -4 dB, `40` adalah -5 dB, `48` adalah -6 dB, `64` adalah -8 dB, `80` adalah -10 dB, dan `96` adalah -12 dB. Proses pemantau yang sedang berjalan akan menerapkan nilai baru dalam waktu satu detik.
