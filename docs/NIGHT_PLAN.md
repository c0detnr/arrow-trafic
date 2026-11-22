# Gece iş planı (Claude yöneticisi için)

Sıra önemli; her aşama sonunda testler + commit + `claude/sweet-allen-sjh6q9` push.

## Aşama 1 — Para kazanma çekirdeği (devam ediyor)
- [ ] İpucu çözücüsü + snapshot/restore (logic.gd)
- [ ] Economy / Ads / IAP servisleri (mock backend'li)
- [ ] Eklenti araştırması → docs/monetization-research.md

## Aşama 2 — Oyuna bağlama
- [ ] HUD: ipucu butonu (sayı rozeti, 0 ise reklam simgesi), ipucu oku parlatma
- [ ] Kayıp paneli: reklam izle → son hamleyi geri al / 1 ipucu ile geri al
- [ ] Mağaza paneli (ana ekran + ipucu bitince): +1 ipucu reklam, ipucu paketleri, reklamları kaldır, destekçi paketi
- [ ] Günlük ödül hapı (ana ekranda, modalsız), yıldızlar
- [ ] Ayarlar: satın alımları geri yükle, gizlilik seçenekleri (UMP)
- [ ] Takılınca (3 engelli dokunuş) ipucu butonu hafifçe nabız atsın

## Aşama 3 — Gerçek eklentiler
- [ ] AdMob adaptörü (services/ads_admob.gd), test reklam kimlikleri
- [ ] Play Billing adaptörü (services/iap_play_billing.gd)
- [ ] export_presets / AD_ID izni / kurulum notları

## Aşama 4 — Mağaza ve uyumluluk
- [ ] store/tr.md, store/en.md metinleri ("rahatsız etmeyen reklam" vurgusu)
- [ ] privacy-policy.html (AdMob, reklam kimliği, satın alma)
- [ ] play-console.md: Veri güvenliği, "Reklam içerir", app-ads.txt

## Aşama 5 — Fazladan değer (zaman kalırsa)
- [ ] Bölüm seçme ekranı (yıldızlarla), seri/ilerleme hissi
- [ ] Günlük bulmaca (tarihe göre seçilen bölüm, ekstra ipucu ödülü)
- [ ] "Bizi değerlendir" (In-App Review) — 20. bölümden sonra tek sefer
- [ ] Ses/titreşim ayarı, dokunma geri bildirimi
- [ ] Kod incelemesi (/code-review), performans, ekran görüntüleri yenileme
- [ ] GOODMORNING.md — sabah yapılacaklar, net adımlarla
