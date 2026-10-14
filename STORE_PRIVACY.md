# Store privacy: risposte e checklist

Bozze per i questionari privacy di App Store Connect e Google Play Console, allineate a
`ios/Runner/PrivacyInfo.xcprivacy` e alle pagine del sito (`repbirds-site/public/`). Se cambia
quello che l'app raccoglie, aggiorna tutti e quattro.

> I testi legali (privacy, termini, eliminazione account) sono una base scritta da Claude:
> falli rivedere a un professionista prima di pubblicarli.

URL da inserire negli store:

| Cosa | URL |
|---|---|
| Privacy policy | https://repbirds.com/privacy |
| Termini (EULA) | https://repbirds.com/terms (o lascia l'EULA standard Apple: i termini lo richiamano) |
| Eliminazione account (Play) | https://repbirds.com/delete-account |
| Supporto | mailto:support@repbirds.com |

## App Store Connect → App Privacy

**Tracking:** No. **Dati usati per tracciarti:** nessuno.

Per ogni tipo: *Collegato all'identità* = Sì, *Tracking* = No, *Scopo* = Funzionalità dell'app.

| Categoria Apple | Tipo | Note |
|---|---|---|
| Informazioni di contatto | Nome | nome e cognome |
| Informazioni di contatto | Indirizzo email | |
| Salute e fitness | Fitness | schede, sessioni, corse |
| Posizione | Posizione precisa | solo durante una corsa avviata dall'utente |
| Contenuti utente | Foto o video | foto profilo e post |
| Contenuti utente | Altri contenuti utente | post, commenti, segnalazioni |
| Identificatori | ID utente | username / id account |
| Altri dati | Altri tipi di dati | data di nascita (verifica età) |

Non dichiarati: Identificatori dispositivo (il token push APNs non è un identificatore del
dispositivo per Apple), Dati di utilizzo e Diagnostica (nessun SDK di analytics o crash).

## Google Play → Data safety

- Raccoglie o condivide dati? **Sì**, raccoglie. **Condivide con terze parti: No** (i fornitori
  che lavorano per noi, come storage e invio email, non contano come condivisione).
- Dati cifrati in transito: **Sì**.
- L'utente può chiedere la cancellazione: **Sì** (in app e su https://repbirds.com/delete-account).
- Conforme alla Families Policy: **No** (app non rivolta a bambini).

| Categoria Play | Tipo | Obbligatorio? | Scopi |
|---|---|---|---|
| Posizione | Posizione precisa | Facoltativo | Funzionalità app |
| Info personali | Nome | Obbligatorio | Funzionalità app, Gestione account |
| Info personali | Indirizzo email | Obbligatorio | Gestione account, Comunicazioni dello sviluppatore |
| Info personali | ID utente | Obbligatorio | Funzionalità app, Gestione account |
| Info personali | Altre info (data di nascita) | Obbligatorio | Gestione account |
| Salute e fitness | Info fitness | Facoltativo | Funzionalità app |
| Foto e video | Foto | Facoltativo | Funzionalità app |
| Attività nell'app | Altri contenuti generati dagli utenti | Facoltativo | Funzionalità app |
| ID dispositivo o altri ID | ID dispositivo (token FCM) | Facoltativo | Funzionalità app (notifiche) |

Tutti "Raccolti", nessuno "Condiviso", nessuno trattato in modo effimero.

## Moderazione (App Store 1.2, Play UGC policy)

Ora nell'app e nell'API:

- **Segnala**: menu "…" su post (schermata del post), commenti e profili → `POST /reports`.
  La segnalazione viene salvata nella tabella `report` e inviata via email a `APP_REPORTS_EMAIL`.
- **Blocca**: stesso menu, blocca chiunque (`POST /friendship/block-user`). Nasconde post e
  commenti nei due sensi, impedisce commenti e richieste di amicizia, silenzia le notifiche.
- **Termini con tolleranza zero** accettati alla registrazione (testo sotto "Crea account").
- **Età minima 14 anni**, controllata in app e nell'API.

## Checklist: cosa resta da fare a mano

**Testi legali**
- [ ] Far rivedere privacy, termini ed eliminazione account a un professionista.
- [x] Completati titolare, indirizzo, provider VPS (Hostinger, Germania) e conservazione (30 giorni).
- [ ] Verificare che il fornitore della VPS e Hostinger abbiano un DPA (accordo sul
      trattamento dati) accettato; Cloudflare lo include nei termini.

**Email e moderazione**
- [ ] Creare la casella `support@repbirds.com` (Hostinger) e leggerla: le segnalazioni vanno
      gestite entro 24 ore e le richieste di cancellazione entro 30 giorni.
- [ ] Impostare `APP_REPORTS_EMAIL=support@repbirds.com` nell'API su Dokploy e fare il deploy
      (la migrazione `V7__report.sql` crea la tabella).
- [ ] Decidere come rimuovere contenuti e account segnalati: oggi a mano dal database
      (`DELETE FROM post WHERE id = …`, `DELETE FROM "user" WHERE id = …`).
- [ ] Una volta al mese: `DELETE FROM report WHERE created_at < now() - interval '12 months';`
      (la privacy promette massimo 12 mesi).

**Sito**
- [x] Pagine `/privacy`, `/terms`, `/delete-account` online su repbirds.com (app Dokploy
      `repbirds-site`, file montati: dopo ogni modifica ai file locali vanno aggiornati i mount
      e ridistribuita l'app).
- [ ] `assetlinks.json` manca ancora in `repbirds-site/public/.well-known/` (serve agli App
      Links Android, vedi DEPLOY.md).

**App Store Connect**
- [ ] Privacy policy URL, support URL, App Privacy come sopra.
- [ ] Age rating: contenuti generati dagli utenti → probabilmente 12+ (rispondi con
      sincerità al questionario: niente contenuti espliciti tollerati).
- [ ] Account demo per la revisione, con qualche dato; nelle note spiega dove sono Segnala,
      Blocca ed Elimina account.

**Google Play Console**
- [ ] Privacy policy URL, Data safety come sopra, URL di eliminazione account.
- [ ] Target audience: 14+ / non rivolta ai bambini. Content rating con UGC.
- [ ] Dichiarazione del foreground service di localizzazione (vedi DEPLOY.md) con video.

**Tecnico**
- [ ] Usare un fornitore di mappe con chiave al posto del server pubblico OpenStreetMap (la
      sua policy vieta l'uso intensivo dalle app), e aggiornare la riga "mappe" della privacy
      con il nome del fornitore.
- [ ] Provare su un dispositivo reale: segnala un post, blocca un utente (i suoi post spariscono
      da Esplora e dal profilo), apri Privacy e Termini da Account, registrazione con data di
      nascita sotto i 14 anni bloccata.
