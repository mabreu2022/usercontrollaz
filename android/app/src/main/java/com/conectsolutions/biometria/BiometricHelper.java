package com.conectsolutions.biometria;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.biometric.BiometricManager;
import androidx.biometric.BiometricPrompt;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.FragmentActivity;

import java.util.concurrent.Executor;

/**
 * Conect Solutions TI - Módulo de Autenticação Biométrica Android
 * Wrapper Java para integração com Free Pascal / Lazarus via JNI.
 * Encapsula a API AndroidX BiometricPrompt.
 */
public class BiometricHelper {

    private static final String TAG = "BiometricHelper";

    // =========================================================================
    // Interfaces de Callback para consumo em Java / Kotlin
    // =========================================================================
    public interface BiometricCallback {
        void onAuthenticationSuccess(String userName);
        void onAuthenticationError(int errorCode, String errorMessage);
    }

    // =========================================================================
    // Assinaturas JNI Nativas - Free Pascal implementará estas procedures (cdecl)
    // =========================================================================
    public static native void onNativeBiometricSuccess(String userName);
    public static native void onNativeBiometricError(int errorCode, String errorMessage);

    /**
     * Verifica se o dispositivo possui hardware biométrico configurado e ativo.
     */
    public static boolean isBiometricAvailable(Context context) {
        if (context == null) return false;
        BiometricManager biometricManager = BiometricManager.from(context);
        int canAuthenticate = biometricManager.canAuthenticate(
                BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.BIOMETRIC_WEAK
        );
        return canAuthenticate == BiometricManager.BIOMETRIC_SUCCESS;
    }

    /**
     * Ponto de entrada estático para disparar o BiometricPrompt a partir do Pascal ou Java.
     *
     * @param activity FragmentActivity atual da aplicação Lazarus
     * @param userName Nome do usuário a ser autenticado (ex: "mauricio")
     * @param callback Callback Java opcional (ou null se chamado direto via JNI)
     */
    public static void showBiometricPrompt(
            @NonNull final FragmentActivity activity,
            @NonNull final String userName,
            final BiometricCallback callback
    ) {
        // Garantir que a execução ocorra estritamente na Thread Principal (UI Thread)
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    // 1. Validar disponibilidade do sensor
                    BiometricManager biometricManager = BiometricManager.from(activity);
                    int authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.BIOMETRIC_WEAK;
                    int authStatus = biometricManager.canAuthenticate(authenticators);

                    if (authStatus != BiometricManager.BIOMETRIC_SUCCESS) {
                        String errMsg;
                        switch (authStatus) {
                            case BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE:
                                errMsg = "Dispositivo não possui sensor biométrico.";
                                break;
                            case BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE:
                                errMsg = "Sensor biométrico temporariamente indisponível.";
                                break;
                            case BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED:
                                errMsg = "Nenhuma digital cadastrada no aparelho.";
                                break;
                            case BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED:
                                errMsg = "Atualização de segurança exigida pelo Android.";
                                break;
                            default:
                                errMsg = "Biometria indisponível (Código: " + authStatus + ")";
                                break;
                        }

                        Log.e(TAG, errMsg);
                        if (callback != null) {
                            callback.onAuthenticationError(authStatus, errMsg);
                        }
                        // Notifica a camada Free Pascal via JNI (com segurança se nativo não linkado)
                        try {
                            onNativeBiometricError(authStatus, errMsg);
                        } catch (UnsatisfiedLinkError ignored) {}
                        return;
                    }

                    // 2. Executor na Thread Principal para receber os eventos
                    Executor executor = ContextCompat.getMainExecutor(activity);

                    // 3. Callback nativo do BiometricPrompt
                    BiometricPrompt biometricPrompt = new BiometricPrompt(
                            activity,
                            executor,
                            new BiometricPrompt.AuthenticationCallback() {
                                @Override
                                public void onAuthenticationError(int errorCode, @NonNull CharSequence errString) {
                                    super.onAuthenticationError(errorCode, errString);
                                    Log.e(TAG, "Falha na autenticação: " + errString + " (Cod: " + errorCode + ")");

                                    if (callback != null) {
                                        callback.onAuthenticationError(errorCode, errString.toString());
                                    }
                                    // Retorna erro para o Free Pascal
                                    try {
                                        onNativeBiometricError(errorCode, errString.toString());
                                    } catch (UnsatisfiedLinkError ignored) {}
                                }

                                @Override
                                public void onAuthenticationSucceeded(@NonNull BiometricPrompt.AuthenticationResult result) {
                                    super.onAuthenticationSucceeded(result);
                                    Log.i(TAG, "Autenticação biométrica realizada com sucesso para o usuário: " + userName);

                                    if (callback != null) {
                                        callback.onAuthenticationSuccess(userName);
                                    }
                                    // Notifica o Free Pascal via JNI para disparar o POST HTTP ao PC
                                    try {
                                        onNativeBiometricSuccess(userName);
                                    } catch (UnsatisfiedLinkError ignored) {}
                                }

                                @Override
                                public void onAuthenticationFailed() {
                                    super.onAuthenticationFailed();
                                    // Leitura de digital não reconhecida; o BiometricPrompt gerencia tentativas internamente
                                    Log.w(TAG, "Digital não reconhecida. Tente novamente.");
                                }
                            }
                    );

                    // 4. Configuração visual do Diálogo Nativo
                    BiometricPrompt.PromptInfo promptInfo = new BiometricPrompt.PromptInfo.Builder()
                            .setTitle("Autenticação Biométrica")
                            .setSubtitle("Use sua digital para liberar o acesso ao sistema VCL")
                            .setDescription("Conect Solutions TI - Verificação de Identidade")
                            .setNegativeButtonText("Cancelar")
                            .setAllowedAuthenticators(authenticators)
                            .build();

                    // 5. Exibir o prompt ao usuário
                    biometricPrompt.authenticate(promptInfo);

                } catch (Exception ex) {
                    Log.e(TAG, "Exceção ao instanciar BiometricPrompt: " + ex.getMessage(), ex);
                    if (callback != null) {
                        callback.onAuthenticationError(-1, ex.getMessage());
                    }
                    try {
                        onNativeBiometricError(-1, "Erro interno: " + ex.getMessage());
                    } catch (UnsatisfiedLinkError ignored) {}
                }
            }
        });
    }

    /**
     * Sobrecarga estática simples para chamadas diretas via JNI a partir do Free Pascal.
     */
    public static void authenticateNative(final FragmentActivity activity, final String userName) {
        showBiometricPrompt(activity, userName, null);
    }
}

