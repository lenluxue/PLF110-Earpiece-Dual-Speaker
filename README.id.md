# PLF110 Earpiece Dual Speaker v2.0.6

[English](README.md) | [简体中文](README.zh-CN.md) | Bahasa Indonesia

Modul KernelSU/Magisk ini telah diuji pada firmware Android 16 untuk OnePlus PLF110.

Modul menetapkan `AUDIO_DEVICE_OUT_SPEAKER` dan `AUDIO_DEVICE_OUT_EARPIECE` sekaligus ke strategi produk media yang sedang aktif (strategi 5 pada firmware Android 16 ini). Indeks media earpiece tetap ditautkan, sehingga perubahan volume media memengaruhi kedua keluaran secara bersamaan. Volume media perangkat keras earpiece dipertahankan pada nilai maksimum (indeks 160) untuk mengimbangi perbedaan kenyaringan yang masih terasa dengan speaker bawah.

Pasang berkas ZIP melalui KernelSU atau Magisk, lalu mulai ulang perangkat. Tombol aksi modul dapat mengaktifkan atau menonaktifkan rute speaker ganda tanpa perlu memulai ulang. Saat modul dihapus, rute tersebut dibersihkan dan indeks perangkat earpiece yang disimpan pada pemasangan pertama akan dipulihkan.

Smart amplifier AW882xx pada speaker bawah diredam secara terpisah melalui kontrol mixer `aw_dev_0_volume`. Nilai bawaannya adalah `96`, setara dengan peredaman 12 dB karena driver AW88265 menggunakan langkah 0,125 dB (`0` adalah pengaturan paling keras). Proses pemantau akan menerapkan kembali nilai ini jika audio HAL mengganti profil. Saat modul aktif, earpiece menggunakan indeks aman maksimum dari kontrol vendor `Handset Volume`, yaitu `0`. Kontrol tersebut juga digunakan bersama oleh panggilan dan pemutaran pesan suara, sehingga jalur audio tersebut mungkin ikut menjadi lebih keras. Saat modul dinonaktifkan atau dihapus, nilai mixer yang tersimpan akan dipulihkan jika valid untuk kontrol perangkat keras.

Perubahan tabel gain dinonaktifkan pada firmware ini karena HAL MediaTek mengalami crash saat memuat ulang tabel yang telah diubah. Modul mempertahankan tabel gain bawaan dan hanya mengatur keseimbangan melalui kontrol volume perangkat secara langsung serta kontrol AW882xx.

Untuk menyetel media saja, tulis offset numerik ke `/data/adb/plf110_earpiece_dual_speaker/earpiece_offset`, lalu tekan tombol aksi modul; offset bawaan adalah 160 langkah volume media.

Untuk menyetel keseimbangan kenyaringan kiri/kanan tanpa membangun ulang modul, tulis bilangan bulat dari `0` hingga `720` ke `/data/adb/plf110_earpiece_dual_speaker/smartpa_attenuation`. Setiap langkah hanya menurunkan speaker bawah sebesar 0,125 dB; contohnya, `24` adalah -3 dB, `32` adalah -4 dB, `40` adalah -5 dB, `48` adalah -6 dB, `64` adalah -8 dB, `80` adalah -10 dB, dan `96` adalah -12 dB. Proses pemantau yang sedang berjalan akan menerapkan nilai baru dalam waktu satu detik.
