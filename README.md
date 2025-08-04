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

## ⚙️ Kurulum

### 1. Gerekli Paketleri Yükleyin

```bash
flutter pub get
