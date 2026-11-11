# Come si pubblica una release di InScheda

La procedura completa, dalla versione nuova alla Release su GitHub con gli APK.
Nell'esempio la versione è la **0.1.3**: sostituisci i numeri con quelli giusti.
I comandi sono per PowerShell (il terminale di VS Code su Windows), dalla cartella del progetto.

## Prima volta su un PC nuovo

Gli APK si firmano con la **upload key**, che **non** è nel repository:

- il file della chiave, `myworkout-upload.jks`, in una cartella fuori dal progetto (es. `C:\Users\<utente>\keys\`), con un backup in un posto sicuro;
- `android/key.properties`, con il percorso della chiave e le password:

  ```properties
  storeFile=C:/Users/<utente>/keys/myworkout-upload.jks
  storePassword=...
  keyAlias=upload
  keyPassword=...
  ```

Tutti e due sono esclusi da git (`android/.gitignore`): **non devono mai finire su GitHub**.
Senza `key.properties` la build funziona lo stesso, ma è firmata con la chiave di debug e non va pubblicata.

## 1. Alza la versione

In `pubspec.yaml`:

```yaml
version: 0.1.3+4
```

- prima del `+`: il nome della versione, quello che vede l'utente;
- dopo il `+`: il numero di build, che deve **sempre crescere** (altrimenti i telefoni non accettano l'aggiornamento).

## 2. Controlla che sia tutto a posto

```powershell
flutter analyze
flutter test
```

Devono dire "No issues found!" e "All tests passed!".

## 3. Compila gli APK

```powershell
flutter build apk --release --split-per-abi
```

Esce un APK per tipo di processore, ~10 MB l'uno. Si pubblicano:

- `app-arm64-v8a-release.apk`: quasi tutti i telefoni;
- `app-armeabi-v7a-release.apk`: telefoni vecchi a 32 bit.

(`app-x86_64-release.apk` serve solo agli emulatori: non si pubblica.)

## 4. Dagli il nome giusto

```powershell
New-Item -ItemType Directory -Force build\app\outputs\flutter-apk\release-0.1.3
Copy-Item build\app\outputs\flutter-apk\app-arm64-v8a-release.apk build\app\outputs\flutter-apk\release-0.1.3\InScheda-0.1.3-arm64.apk
Copy-Item build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk build\app\outputs\flutter-apk\release-0.1.3\InScheda-0.1.3-arm32.apk
```

Controllo della firma (facoltativo, ma utile):

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\37.0.0\apksigner.bat" verify --print-certs build\app\outputs\flutter-apk\release-0.1.3\InScheda-0.1.3-arm64.apk
```

Deve comparire `CN=myWorkout, O=salvatorenapolano` (è il nome interno della chiave: va bene così).
Se compare **"Android Debug"**, manca `key.properties`: **non pubblicare** quell'APK.

## 5. Commit, tag e push

```powershell
git status
git add -A
git commit -m "Versione 0.1.3: cosa è cambiato"
git tag -a v0.1.3 -m "InScheda 0.1.3"
git push --follow-tags
```

- In `git status` **non** devono comparire file `.jks` né `key.properties`.
- `--follow-tags` manda su GitHub anche il tag.

## 6. Release su GitHub

1. Su <https://github.com/salvatorenapolano/InScheda> → **Releases** → **Draft a new release**.
2. **Choose a tag** → `v0.1.3`.
3. Titolo (es. "InScheda 0.1.3 — …") e note:
   - cosa c'è di nuovo;
   - quale APK scaricare (arm64 per quasi tutti, arm32 solo per telefoni molto vecchi);
   - "Hai già InScheda? Installa sopra: i tuoi dati restano";
   - "Serve Android 7.0 o più recente".
4. Trascina i due APK della cartella `release-0.1.3` in **Attach binaries**.
5. **Publish release** (non "Save draft"). Controlla che sia segnata **Latest**.

## Se qualcosa va storto

- **Il telefono non installa l'aggiornamento**: il numero dopo il `+` non è cresciuto, oppure l'APK è firmato con un'altra chiave.
- **Tag sbagliato prima del push**: `git tag -d v0.1.3` e ricrealo. Dopo il push, meglio fare una versione nuova che riscrivere un tag già pubblico.
- **Release rimasta in bozza**: in Releases compare "Draft"; aprila con la matita e premi **Publish release**.
