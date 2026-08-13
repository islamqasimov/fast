# Cost Control — $300 Krediti Qorumaq

Bu layihə GCP-nin yeni-hesab $300 / 90-gün kreditindən istifadə edir.
Kredit bitəndə (və ya vaxt keçəndə) VM-lər PULLU olacaq. Aşağıdakı
qaydalara ciddi əməl et.

## 1. Budget Alert Qur (İLK ADDIM, VM yaratmazdan ƏVVƏL)

GCP Console → **Billing → Budgets & Alerts → Create Budget**

- Büdcə: $20 (təhlükəsizlik zolağı)
- Alert threshold-ları: 50%, 90%, 100%
- Email bildirişi öz ünvanına

Bu, kreditin gözlənilmədən əriməsinin qarşısını alır.

## 2. Təxmini Aylıq Xərc (VM-lər 24/7 işlədikdə)

| VM | Machine Type | Təxmini $/ay (24/7) |
|---|---|---|
| wazuh-manager | e2-standard-4 | ~$100 |
| ioc-collector | e2-small | ~$14 |
| linux-target | e2-medium | ~$25 |
| **Cəmi** | | **~$139/ay** |

Hamısı Ubuntu (heç bir OS lisenziya haqqı yoxdur — yalnız compute).
$300 kredit ilə 24/7 işlədikdə **~2 ay** işləyir.

## 3. İstifadə Etmədiyin Vaxt VM-ləri STOP Et

```bash
# İşi bitirəndə (gün sonu və s.)
gcloud compute instances stop wazuh-manager ioc-collector linux-target --zone=us-central1-a

# Yenidən işə salanda
gcloud compute instances start wazuh-manager ioc-collector linux-target --zone=us-central1-a
```

**Stopped VM üçün yalnız disk haqqı tutulur** (~$5-10/ay cəmi 3 VM üçün),
compute haqqı tutulmur. Bu, krediti bir neçə dəfə uzada bilər.

> ⚠️ `terraform destroy`/`apply` ETMƏ sadəcə fasilə üçün — bu, hər dəfə
> yeni IP və sıfırdan konfiqurasiya deməkdir. Sadəcə `stop`/`start` kifayətdir.

## 4. İş Tam Bitəndə — Hər Şeyi Sil

```bash
cd infra/terraform
terraform destroy
```

Bu, bütün VM-ləri, diskləri, şəbəkəni silir — $0 xərcə qayıdır.

## 5. Xərci İzləmək

```bash
# Cari ay xərci
gcloud billing accounts list
gcloud alpha billing accounts get-spend-information ACCOUNT_ID
```

Və ya sadəcə GCP Console → Billing → Reports.

## 6. Əlavə Qorunma

- Kredit kartı ilə "avtomatik yükləmə" seçimini SÖNDÜR (GCP-də adətən
  default deyil, amma yoxla: Billing → Payment settings)
- Layihəni tamamlayandan sonra layihəni özünü sil (Console → IAM & Admin
  → Manage Resources → Delete Project) — bu, unudulmuş resursların
  qarşısını 100% alır
