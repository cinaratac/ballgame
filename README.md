# 🎯 Renkli Portal Vuruşu

Bu oyun, reflekslerinizi ve hafızanızı test eden eğlenceli bir nişan oyunudur. Oyuncu, ortada dönen bir okla doğru portallara beyaz toplar gönderir. Amaç doğru renklere isabet ettirip puan kazanmak, yanlış renklere vurduğunuzda ise cezalandırılmaktır. İlerleyen seviyelerde hız artar ve renkler kaybolur!

## 🕹️ Oynanış

- Ortada dönen bir ok var. Ekrana dokunarak topu fırlatırsınız.
- Portallar sabit ya da dönen olabilir.
- Mavi portal: Puan kazandırır.
- Kırmızı portal: Cezalandırır, puan kaybettirir veya oyun sıfırlanabilir.
- Yeşil portal: Size ekstra can kazandırır.
- Turuncu küre: Oku yakalarsa kaybedersiniz.
- Bazı seviyelerde portalların renkleri bir süre sonra **maskelenir (beyaza döner)**. Renkleri hafızanızla hatırlayıp doğru portala atış yapmalısınız!

## 🧠 Seviye Mekanikleri

- Level 1–25: Temel renkli portal mekanikleri. Zorluk artar.
- Level 26: Portallar dönmez, renkler maskelenir.
- Level 27–40:
  - Portallar yavaşça dönmeye başlar ve seviye ilerledikçe hızlanır.
  - Ortadaki okun hızı düşürülmüştür.
  - Portal sayısı yavaşça artar.
  - Renk maskesi ve hafıza oyunu devrede.

🛍️ Mağaza

Oyunda toplanan puanlar ile farklı ok görünümleri satın alınabilir. Ok envanteri, mağaza arayüzü üzerinden yönetilebilir.

💾 Kalıcılık
	•	Oyun seviyesi, toplam puan ve envanter (ok görünümleri), cihazda SharedPreferences ile saklanır.
	•	Oyunu kapatsanız bile kaldığınız yerden devam edebilirsiniz.

🎨 Kullanılan Teknolojiler
	•	Flutter + Flame Game Engine
	•	Shared Preferences (veri saklama)
	•	Custom canvas rendering
	•	Audioplayers (ses efektleri)

🧪 Geliştirici Notları
	•	Level 13–17 arası kırmızı “ölüm çemberi” aktif olur.
	•	Level 18–25 arası yön değiştiren portallar bulunur.
	•	Level 26’da top fırlatma 5 saniye engellenir, sonra renkler maskelenir.
	•	Level 27’den sonra portal dönüş hızı her seviyede biraz daha artar.


Geliştiriciler: Çınar Atakul, Mehmet adil, Rıza Dinçer, İris Uysal
