# mac-dev-plugins

Marketplace di plugin per Claude Code dedicato allo sviluppo macOS nativo. Contiene **swift-harness**: un metodo di lavoro riutilizzabile che mantiene Claude Code coerente sui progetti Swift/SwiftUI man mano che crescono.

[Read in English](README.md)

## Perché

I piani step by step tengono ogni sessione concentrata, ma non impediscono la deriva tra uno step e l'altro. Con la crescita del progetto lo stesso elemento (una pillola di notifica in alto, un bottone con hover, un popover) viene ricostruito in modo leggermente diverso in ogni feature, i valori grezzi si spargono nelle view e arrivano bug visivi e strutturali.

swift-harness interviene su tre livelli:

1. **Il design system sta nel codice**, non nei documenti: token e componenti condivisi in un Swift package locale.
2. **Claude sa dove guardare**: un `CLAUDE.md` corto, rules legate ai percorsi, un registro dei componenti e gli ADR, caricati solo quando servono.
3. **I controlli sono automatici**, non richieste: gli hook formattano, controllano e verificano, quindi "non mettere valori a mano" diventa qualcosa che Claude non può saltare.

## Cosa contiene

| Tipo | Nome | Cosa fa |
|---|---|---|
| Skill (la lanci tu) | `/swift-harness:setup` | Prepara un progetto nuovo o esistente: `CLAUDE.md`, `.claude/rules/`, `docs/` (architettura, design system, registro componenti, template ADR), `.swiftlint.yml`, formatter, `scripts/verify.sh`, config degli hook. Non sovrascrive mai file esistenti. |
| Skill (la lanci tu) | `/swift-harness:audit` | Audit in sola lettura di architettura, coerenza della UI e salute del codice, con report e piano di migrazione. |
| Skill (automatica) | `ui-change` | Procedura "riusa prima di creare" per ogni modifica di interfaccia. |
| Skill (automatica) | `design-system` | Struttura del package, token, presenter condiviso per pillole e toast, stili dei bottoni, gallery, snapshot test, migrazione dai valori hardcoded. Con file Swift di riferimento. |
| Skill (automatica) | `feature` | Ciclo Discover, Plan, Implement, Verify, Record per ogni feature o step. |
| Skill (automatica) | `adr` | Registra una decisione architetturale e la indicizza. |
| Subagent | `ui-reviewer` | Review in sola lettura di un diff contro design system, registro e regole di architettura. |
| Hook | SessionStart | Fissa lo stato di partenza del codice come riferimento (non come verificato), avvisa se l'ultima verifica è fallita sullo stesso codice e segnala strumenti mancanti. |
| Hook | PreToolUse | Chiede conferma prima che Claude modifichi `project.pbxproj` o un percorso protetto con i tool Edit o Write. Non è una sandbox: vedi [Limiti](#limiti). |
| Hook | PostToolUse | Formatta e controlla il file Swift appena modificato (solo file dentro il progetto); risultati del lint, errori del formatter ed errori di configurazione di SwiftLint tornano a Claude. |
| Hook | Stop | Esegue la verifica veloce prima che Claude chiuda il turno, solo se sono cambiati input della build (codice Swift, impostazioni di progetto e build, risorse). |

Gli hook sono **spenti in ogni progetto che non contiene `.claude/swift-harness.json`**: gli altri progetti non vengono toccati.

### Come si comporta il controllo a fine turno

- Codice invariato dall'inizio della sessione o dall'ultima verifica riuscita: non parte nulla. Lo stato di partenza è un riferimento, non una verifica superata: se era già rotto, la prima modifica della sessione fa partire la verifica e lo mostra.
- Codice cambiato e verifica fallita: Claude viene bloccato e riceve le ultime 60 righe dell'output.
- Claude prova a fermarsi di nuovo senza modificare nulla: può fermarsi, e ricevi un avviso.
- Dopo `maxAttempts` fallimenti consecutivi (default 3): si ferma e decidi tu.
- Con `lintBlocking: true`, i file che non hanno passato SwiftLint dopo una modifica vengono ricontrollati qui. Un hook non può annullare una modifica già fatta, quindi è qui che viene intercettata: il turno non risulta superato finché quei file non sono puliti.
- "Cambiato" vale per ogni input della build: file Swift, `Package.resolved`, `.pbxproj`, `.xcconfig`, plist, entitlements, cataloghi di asset e stringhe, cartelle `Resources/`, snapshot di riferimento, `scripts/`, configurazione di lint e dell'harness. `.build` e DerivedData sono ignorati.
- Un fallimento sopravvive a una nuova sessione: all'avvio o al resume Claude viene avvisato se l'ultima verifica è fallita sul codice attuale.
- Funziona per worktree, quindi agenti paralleli verificano ciascuno la propria copia.

## Requisiti

- macOS con Xcode
- Claude Code con supporto ai plugin
- `jq` (necessario per gli hook), `swiftlint` e `swiftformat` (consigliati)

```bash
brew install jq swiftlint swiftformat
```

## Installazione

In Claude Code:

```
/plugin marketplace add davidelarocca/mac-dev-plugins
/plugin install swift-harness@mac-dev-plugins
/plugin install swift-lsp@claude-plugins-official
```

## Uso

1. Apri il progetto in Claude Code e fai commit del lavoro in sospeso.
2. Lancia `/swift-harness:setup`. Rileva la struttura, fa al massimo quattro domande e genera i file su un branch `chore/swift-harness-setup`.
3. Per un progetto già avviato, passa in plan mode e lancia `/swift-harness:audit`.
4. Da lì in poi `ui-change`, `feature`, `design-system` e `adr` si attivano da sole e gli hook lavorano in automatico.

## Configurazione

`.claude/swift-harness.json` nel progetto:

```json
{
  "format": "swiftformat",
  "lint": "swiftlint",
  "lintBlocking": false,
  "verify": { "enabled": true, "command": "scripts/verify.sh fast", "maxAttempts": 3 },
  "protectedPaths": ["Sources/Audio/"],
  "guardPbxproj": true
}
```

- `format`: `swiftformat`, `swift-format` (quello di Apple, incluso in Xcode) o `none`.
- `lintBlocking`: `true` blocca Claude sugli errori SwiftLint, e anche quando SwiftLint non riesce a girare o segnala una configurazione non valida; quei file vengono ricontrollati a fine turno. Con `false` Claude riceve solo il report. Da attivare a migrazione finita.
- `verify.command`: qualsiasi comando; codice di uscita 0 significa verifica superata.
- `protectedPaths`: prefissi relativi alla radice del repository che richiedono conferma prima di un Edit o Write (`../` e symlink vengono risolti, anche quando la voce stessa è un symlink).
- `scripts/verify.sh` non dichiara mai PASS senza aver eseguito almeno un controllo: senza scheme né package fallisce con `NOT CONFIGURED`, e un package elencato ma inesistente è un fallimento.

La tabella completa delle opzioni e delle regole SwiftLint è nel [README in inglese](README.md#configuration).

## Aggiornare

Modifica il plugin, alza `version` in `plugins/swift-harness/.claude-plugin/plugin.json`, fai push e in Claude Code lancia `/plugin marketplace update mac-dev-plugins`. Prima del push lancia `tests/run.sh`: richiede solo bash, git e jq (`xcodebuild` e `swift` sono simulati). Per provare modifiche locali senza reinstallare: `claude --plugin-dir ./plugins/swift-harness`.

## Limiti

- I file Swift di riferimento della skill `design-system` sono esempi da adattare, non una libreria.
- Gli snapshot test cambiano tra versioni di macOS: registrali ed eseguili sullo stesso sistema, e rigenerali dopo aggiornamenti importanti.
- Il guard sui percorsi protetti copre solo i tool Edit, Write e MultiEdit. Un comando shell eseguito via Bash può comunque modificare un file protetto. Per limiti rigidi usa le [regole di permesso](https://code.claude.com/docs/en/permissions) di Claude Code (`deny`) e considera il guard una protezione contro modifiche accidentali, non una sandbox.
- `verify.command` viene eseguito come comando shell nel progetto. Con il plugin attivo, qualsiasi repository che contiene `.claude/swift-harness.json` può eseguire i propri comandi quando Claude chiude un turno. Usalo su progetti di cui ti fidi.

## Licenza

[MIT](LICENSE)
