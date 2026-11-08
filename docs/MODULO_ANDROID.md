# Módulo 1: O Wrapper Android (Java / Gradle)
**Conect Solutions TI** — Engenharia de Sistemas Distribuídos e Mobile Cross-Platform

Este módulo é responsável por fazer a interface direta com os sensores de impressão digital do sistema operacional Android utilizando a biblioteca padrão moderna da Google (`androidx.biometric:biometric:1.1.0`).

---

## 1. Estrutura de Arquivos

* `android/app/build.gradle`: Configuração de compilação do Gradle e dependências.
* `android/app/src/main/AndroidManifest.xml`: Manifesto com permissões e flags de rede.
* `android/app/src/main/java/com/conectsolutions/biometria/BiometricHelper.java`: Classe utilitária do diálogo biométrico e declaração dos métodos nativos JNI.
* `android/app/src/main/java/com/conectsolutions/biometria/MainActivity.java`: Activity principal com interface gráfica completa de teste e disparo do HTTP POST.

---

## 2. Configuração do Gradle (`build.gradle`)

No arquivo `android/app/build.gradle`, declaramos a biblioteca oficial do AndroidX Biometric e o suporte base a Fragments (obrigatório para a `FragmentActivity`):

```groovy
dependencies {
    // Biblioteca oficial de Biometria da Google
    implementation 'androidx.biometric:biometric:1.1.0'
    
    // Suporte base a AppCompat e Fragments
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.core:core:1.12.0'
    implementation 'com.google.android.material:material:1.11.0'
}
```

---

## 3. Manifesto Android (`AndroidManifest.xml`)

As seguintes permissões são exigidas para leitura biométrica e envio em rede local:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Permissões Biométrica moderna e legado -->
    <uses-permission android:name="android.permission.USE_BIOMETRIC" />
    <uses-permission android:name="android.permission.USE_FINGERPRINT" />

    <!-- Permissões de Comunicação em Rede Local -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />

    <application
        android:label="Biometria Conect"
        android:theme="@style/Theme.BiometriaLazarus"
        android:usesCleartextTraffic="true">
        <!-- 
          usesCleartextTraffic="true" é CRÍTICO:
          Permite que o aplicativo converse via HTTP sem criptografia SSL
          com os computadores da rede local (ex: http://192.168.15.119:8080).
        -->
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

---

## 4. O Wrapper Java (`BiometricHelper.java`)

### 4.1. Verificação Prévia de Hardware
Antes de invocar o diálogo, o método estático `isBiometricAvailable` consulta o `BiometricManager` para certificar-se de que o aparelho possui sensor ativo e pelo menos uma digital cadastrada:

```java
BiometricManager biometricManager = BiometricManager.from(context);
int canAuthenticate = biometricManager.canAuthenticate(
    BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.BIOMETRIC_WEAK
);
```

### 4.2. Exibição do Diálogo Nativo (`showBiometricPrompt`)
O prompt é executado estritamente na Thread Principal (`activity.runOnUiThread`):

```java
BiometricPrompt.PromptInfo promptInfo = new BiometricPrompt.PromptInfo.Builder()
    .setTitle("Autenticação Biométrica")
    .setSubtitle("Use sua digital para liberar o acesso ao sistema VCL")
    .setDescription("Conect Solutions TI - Verificação de Identidade")
    .setNegativeButtonText("Cancelar")
    .setAllowedAuthenticators(authenticators)
    .build();

biometricPrompt.authenticate(promptInfo);
```

### 4.3. Callbacks JNI Nativas para o Free Pascal
A classe define dois métodos estáticos nativos que notificam a biblioteca compartilhada compilada pelo Lazarus (`libcontrols.so`):

```java
public static native void onNativeBiometricSuccess(String userName);
public static native void onNativeBiometricError(int errorCode, String errorMessage);
```

Essas chamadas são envolvidas em blocos `try/catch (UnsatisfiedLinkError)` para permitir que a classe funcione de forma autônoma mesmo durante testes em que o código compilado em Pascal ainda não foi carregado na memória da JVM.
