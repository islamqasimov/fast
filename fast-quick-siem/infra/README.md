# ⚠️ Status: Alternativ / Arxivlənmiş Yanaşma

Bu qovluqdakı Terraform + Ansible əsaslı, çoxlu-VM cloud infrastrukturu
layihənin **ilkin** planı idi. Layihənin əsas məqsədi — *"tez bir zamanda
SIEM qaldırmaq"* və *"qısamüddətli tədbirlərdə hazır mühit"* — nəzərə
alınaraq, bu yanaşma **fast deployment** tələbini ödəmədiyi üçün (IAM
konfiqurasiyası, çoxlu VM yaratma, Ansible playbook-ları — ümumilikdə
saatlarla vaxt) əsas yoldan çıxarılıb.

**Cari, tövsiyə olunan deployment yolu:** layihənin kök qovluğundakı
`deploy.sh` — Docker Compose əsaslı, tək əmrlə, 5-10 dəqiqədə tam mühiti
ayağa qaldırır. Bax: `docs/DEPLOYMENT_GUIDE.md`.

Bu qovluq (`infra/`) yalnız **öyrənmə və gələcək genişlənmə** məqsədilə
saxlanılıb — məsələn, layihə uzunmüddətli/institusional istifadəyə
keçərsə, IaC əsaslı, çoxlu-VM, təkrarlana bilən cloud infrastrukturu
lazım ola bilər. Hazırkı halda istifadə olunması **tövsiyə edilmir**.
