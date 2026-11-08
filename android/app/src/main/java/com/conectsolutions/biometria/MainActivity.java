package com.conectsolutions.biometria;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Conect Solutions TI - Activity Principal Android
 * Integração BiometricPrompt -> Microserviço VCL via HTTP POST
 */
public class MainActivity extends AppCompatActivity {

    private static final String TAG = "MainActivity";

    private EditText edtPCIp;
    private EditText edtPort;
    private EditText edtUser;
    private Button btnAutenticar;
    private TextView txtStatus;
    private TextView txtLogs;

    private final ExecutorService executorService = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        edtPCIp = findViewById(R.id.edtPCIp);
        edtPort = findViewById(R.id.edtPort);
        edtUser = findViewById(R.id.edtUser);
        btnAutenticar = findViewById(R.id.btnAutenticar);
        txtStatus = findViewById(R.id.txtStatus);
        txtLogs = findViewById(R.id.txtLogs);

        appendLog("App inicializado. Sensor biométrico pronto.");

        btnAutenticar.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                iniciarAutenticacao();
            }
        });
    }

    private void iniciarAutenticacao() {
        final String ip = edtPCIp.getText().toString().trim();
        final String port = edtPort.getText().toString().trim();
        final String user = edtUser.getText().toString().trim();

        if (ip.isEmpty()) {
            Toast.makeText(this, "Informe o IP do PC", Toast.LENGTH_SHORT).show();
            return;
        }

        txtStatus.setText("Aguardando leitura da sua digital no sensor...");
        txtStatus.setBackgroundColor(0xFFE8EAF6);
        appendLog("Acionando BiometricPrompt para o usuário: " + user);

        BiometricHelper.showBiometricPrompt(this, user, new BiometricHelper.BiometricCallback() {
            @Override
            public void onAuthenticationSuccess(final String userName) {
                mainHandler.post(new Runnable() {
                    @Override
                    public void run() {
                        txtStatus.setText("Digital confirmada! Enviando liberação para o PC...");
                        txtStatus.setBackgroundColor(0xFFC8E6C9); // Verde claro
                        appendLog("SUCESSO: Biometria validada para " + userName);

                        // Dispara envio HTTP assíncrono em segundo plano
                        enviarConfirmacaoAoPC(ip, port, userName);
                    }
                });
            }

            @Override
            public void onAuthenticationError(final int errorCode, final String errorMessage) {
                mainHandler.post(new Runnable() {
                    @Override
                    public void run() {
                        txtStatus.setText("Erro na biometria: " + errorMessage);
                        txtStatus.setBackgroundColor(0xFFFFCDD2); // Vermelho claro
                        appendLog("FALHA (" + errorCode + "): " + errorMessage);
                    }
                });
            }
        });
    }

    private void enviarConfirmacaoAoPC(final String ip, final String port, final String user) {
        executorService.execute(new Runnable() {
            @Override
            public void run() {
                final String targetUrl = "http://" + ip + ":" + port + "/biometria-sucesso";
                final String jsonPayload = "{\"user\": \"" + user + "\", \"status\": \"approved\"}";

                appendLog("[HTTP] POST " + targetUrl);
                appendLog("[HTTP] Payload: " + jsonPayload);

                HttpURLConnection conn = null;
                try {
                    URL url = new URL(targetUrl);
                    conn = (HttpURLConnection) url.openConnection();
                    conn.setRequestMethod("POST");
                    conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                    conn.setRequestProperty("User-Agent", "ConectSolutions-Android-App/1.0");
                    conn.setConnectTimeout(5000);
                    conn.setReadTimeout(5000);
                    conn.setDoOutput(true);

                    // Escreve o corpo da requisição
                    try (OutputStream os = conn.getOutputStream()) {
                        byte[] input = jsonPayload.getBytes(StandardCharsets.UTF_8);
                        os.write(input, 0, input.length);
                        os.flush();
                    }

                    final int responseCode = conn.getResponseCode();
                    final StringBuilder responseBody = new StringBuilder();

                    try (BufferedReader br = new BufferedReader(
                            new InputStreamReader(
                                    responseCode >= 200 && responseCode < 300
                                            ? conn.getInputStream()
                                            : conn.getErrorStream(),
                                    StandardCharsets.UTF_8
                            )
                    )) {
                        String line;
                        while ((line = br.readLine()) != null) {
                            responseBody.append(line);
                        }
                    }

                    final String result = responseBody.toString();
                    Log.i(TAG, "Resposta do PC (" + responseCode + "): " + result);

                    mainHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            if (responseCode == 200) {
                                txtStatus.setText("ACESSO LIBERADO NO SISTEMA VCL COM SUCESSO!");
                                txtStatus.setBackgroundColor(0xFF81C784); // Verde vibrante
                                appendLog("RESPOSTA 200 OK: " + result);
                                Toast.makeText(MainActivity.this, "Acesso VCL Liberado!", Toast.LENGTH_LONG).show();
                            } else {
                                txtStatus.setText("Servidor VCL recusou (Código " + responseCode + ")");
                                txtStatus.setBackgroundColor(0xFFFFB74D); // Laranja
                                appendLog("RESPOSTA " + responseCode + ": " + result);
                            }
                        }
                    });

                } catch (final Exception e) {
                    Log.e(TAG, "Erro ao conectar no PC: " + e.getMessage(), e);
                    mainHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            txtStatus.setText("Erro de rede: " + e.getMessage());
                            txtStatus.setBackgroundColor(0xFFFFCDD2);
                            appendLog("ERRO DE CONEXÃO: " + e.getMessage());
                            appendLog("Dica: Verifique se o ServerVCL.exe está rodando e na mesma rede.");
                        }
                    });
                } finally {
                    if (conn != null) {
                        conn.disconnect();
                    }
                }
            }
        });
    }

    private void appendLog(final String msg) {
        mainHandler.post(new Runnable() {
            @Override
            public void run() {
                String time = new SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(new Date());
                String line = "[" + time + "] " + msg + "\n";
                txtLogs.append(line);
            }
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        executorService.shutdown();
    }
}
