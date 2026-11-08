package com.conectsolutions.biometria;

import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.biometric.BiometricManager;

import com.google.android.material.tabs.TabLayout;

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
 * Conect Solutions TI - Activity Principal Android com Abas
 * 1. Login VCL
 * 2. Aprovação PDV (2FA)
 * 3. Meu Dispositivo (UserControl)
 */
public class MainActivity extends AppCompatActivity {

    private static final String TAG = "MainActivity";

    private TabLayout tabLayout;
    private LinearLayout layoutTabLogin;
    private LinearLayout layoutTabPDV;
    private LinearLayout layoutTabDispositivo;

    // Campos Aba 1 (Login)
    private EditText edtPCIp;
    private EditText edtPort;
    private EditText edtUser;
    private Button btnAutenticar;
    private Button btnCadastrarNovoDedo;

    // Campos Aba 2 (PDV)
    private Button btnAprovarPDV;

    // Campos Aba 3 (Dispositivo)
    private TextView txtModeloAparelho;
    private TextView txtDeviceId;
    private TextView txtUsuarioVinculado;
    private Button btnTestarConexao;
    private Button btnCadastrarNovoDedoTab3;

    // Feedback comum
    private TextView txtStatus;
    private TextView txtLogs;

    private String deviceIdValue = "";
    private final ExecutorService executorService = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // Mapeamento dos componentes de abas
        tabLayout = findViewById(R.id.tabLayout);
        layoutTabLogin = findViewById(R.id.layoutTabLogin);
        layoutTabPDV = findViewById(R.id.layoutTabPDV);
        layoutTabDispositivo = findViewById(R.id.layoutTabDispositivo);

        // Mapeamento Aba 1
        edtPCIp = findViewById(R.id.edtPCIp);
        edtPort = findViewById(R.id.edtPort);
        edtUser = findViewById(R.id.edtUser);
        btnAutenticar = findViewById(R.id.btnAutenticar);
        btnCadastrarNovoDedo = findViewById(R.id.btnCadastrarNovoDedo);

        // Mapeamento Aba 2
        btnAprovarPDV = findViewById(R.id.btnAprovarPDV);

        // Mapeamento Aba 3
        txtModeloAparelho = findViewById(R.id.txtModeloAparelho);
        txtDeviceId = findViewById(R.id.txtDeviceId);
        txtUsuarioVinculado = findViewById(R.id.txtUsuarioVinculado);
        btnTestarConexao = findViewById(R.id.btnTestarConexao);
        btnCadastrarNovoDedoTab3 = findViewById(R.id.btnCadastrarNovoDedoTab3);

        // Feedback
        txtStatus = findViewById(R.id.txtStatus);
        txtLogs = findViewById(R.id.txtLogs);

        // Identificação única do dispositivo (UserControl DeviceId)
        try {
            String androidId = Settings.Secure.getString(getContentResolver(), Settings.Secure.ANDROID_ID);
            deviceIdValue = Build.MODEL + "-" + (androidId != null ? androidId : "DEV01");
        } catch (Exception e) {
            deviceIdValue = Build.MODEL + "-UNKNOWN";
        }

        txtModeloAparelho.setText(Build.MANUFACTURER + " " + Build.MODEL);
        txtDeviceId.setText(deviceIdValue);

        appendLog("App Conect Solutions iniciado.");
        appendLog("Aparelho: " + Build.MODEL + " | DeviceID: " + deviceIdValue);

        // Controle de alternância de abas
        tabLayout.addOnTabSelectedListener(new TabLayout.OnTabSelectedListener() {
            @Override
            public void onTabSelected(TabLayout.Tab tab) {
                alternarAba(tab.getPosition());
            }

            @Override
            public void onTabUnselected(TabLayout.Tab tab) {}

            @Override
            public void onTabReselected(TabLayout.Tab tab) {}
        });

        // Ação Aba 1: Autenticar Login
        btnAutenticar.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dispararBiometria("login");
            }
        });

        // Ação Aba 2: Aprovação Gerencial de PDV (2FA)
        btnAprovarPDV.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dispararBiometria("aprovacao_pdv");
            }
        });

        // Ação: Cadastrar Nova Digital no Android
        View.OnClickListener clickCadastrarDedo = new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                abrirCadastroBiometriaAndroid();
            }
        };

        btnCadastrarNovoDedo.setOnClickListener(clickCadastrarDedo);
        btnCadastrarNovoDedoTab3.setOnClickListener(clickCadastrarDedo);

        // Ação Aba 3: Testar Conexão
        btnTestarConexao.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                testarConexaoServidor();
            }
        });
    }

    /**
     * Aciona diretamente o Assistente Oficial da Samsung / Android
     * para cadastrar novos dedos de colaboradores sem precisar caçar nas configurações!
     */
    private void abrirCadastroBiometriaAndroid() {
        appendLog("Abrindo assistente nativo para cadastrar novo dedo...");
        txtStatus.setText("Cadastre a digital no assistente do Android e volte ao app.");
        txtStatus.setBackgroundColor(0xFFE8EAF6);

        try {
            Intent enrollIntent;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                enrollIntent = new Intent(Settings.ACTION_BIOMETRIC_ENROLL);
                enrollIntent.putExtra(Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                        BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.BIOMETRIC_WEAK);
            } else {
                enrollIntent = new Intent(Settings.ACTION_SECURITY_SETTINGS);
            }
            startActivity(enrollIntent);
        } catch (Exception e) {
            try {
                startActivity(new Intent(Settings.ACTION_SECURITY_SETTINGS));
            } catch (Exception ex) {
                Toast.makeText(this, "Abra Configurações > Segurança para cadastrar a digital.", Toast.LENGTH_LONG).show();
            }
        }
    }

    private void alternarAba(int posicao) {
        layoutTabLogin.setVisibility(posicao == 0 ? View.VISIBLE : View.GONE);
        layoutTabPDV.setVisibility(posicao == 1 ? View.VISIBLE : View.GONE);
        layoutTabDispositivo.setVisibility(posicao == 2 ? View.VISIBLE : View.GONE);

        switch (posicao) {
            case 0:
                txtStatus.setText("Aba 1: Login VCL selecionada.");
                break;
            case 1:
                txtStatus.setText("Aba 2: Aprovação Gerencial de PDV selecionada.");
                break;
            case 2:
                txtStatus.setText("Aba 3: Informações do Aparelho (UserControl).");
                break;
        }
    }

    private void dispararBiometria(final String operacao) {
        final String ip = edtPCIp.getText().toString().trim();
        final String port = edtPort.getText().toString().trim();
        final String user = edtUser.getText().toString().trim();

        if (ip.isEmpty()) {
            Toast.makeText(this, "Informe o IP do PC", Toast.LENGTH_SHORT).show();
            return;
        }

        txtStatus.setText("Aguardando leitura da sua digital no sensor...");
        txtStatus.setBackgroundColor(0xFFE8EAF6);
        appendLog("Acionando BiometricPrompt (" + operacao + ") para o usuário: " + user);

        BiometricHelper.showBiometricPrompt(this, user, new BiometricHelper.BiometricCallback() {
            @Override
            public void onAuthenticationSuccess(final String userName) {
                mainHandler.post(new Runnable() {
                    @Override
                    public void run() {
                        txtStatus.setText("Digital confirmada! Enviando dados ao PC...");
                        txtStatus.setBackgroundColor(0xFFC8E6C9);
                        appendLog("SUCESSO: Biometria validada para " + userName);

                        enviarConfirmacaoAoPC(ip, port, userName, operacao);
                    }
                });
            }

            @Override
            public void onAuthenticationError(final int errorCode, final String errorMessage) {
                mainHandler.post(new Runnable() {
                    @Override
                    public void run() {
                        txtStatus.setText("Falha na biometria: " + errorMessage);
                        txtStatus.setBackgroundColor(0xFFFFCDD2);
                        appendLog("FALHA (" + errorCode + "): " + errorMessage);
                    }
                });
            }
        });
    }

    private void enviarConfirmacaoAoPC(final String ip, final String port, final String user, final String operacao) {
        executorService.execute(new Runnable() {
            @Override
            public void run() {
                final String targetUrl = "http://" + ip + ":" + port + "/biometria-sucesso";
                final String jsonPayload = "{"
                        + "\"user\": \"" + user + "\", "
                        + "\"status\": \"approved\", "
                        + "\"device_id\": \"" + deviceIdValue + "\", "
                        + "\"operation\": \"" + operacao + "\""
                        + "}";

                appendLog("[HTTP] POST " + targetUrl);

                HttpURLConnection conn = null;
                try {
                    URL url = new URL(targetUrl);
                    conn = (HttpURLConnection) url.openConnection();
                    conn.setRequestMethod("POST");
                    conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                    conn.setRequestProperty("User-Agent", "ConectSolutions-Android-App/2.0");
                    conn.setConnectTimeout(5000);
                    conn.setReadTimeout(5000);
                    conn.setDoOutput(true);

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

                    mainHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            if (responseCode == 200) {
                                txtStatus.setText("ACESSO APROVADO NO SISTEMA VCL!");
                                txtStatus.setBackgroundColor(0xFF81C784);
                                appendLog("200 OK: " + result);
                                Toast.makeText(MainActivity.this, "Autorizado com Sucesso!", Toast.LENGTH_SHORT).show();
                            } else {
                                txtStatus.setText("Recusado pelo Servidor (Código " + responseCode + ")");
                                txtStatus.setBackgroundColor(0xFFFFB74D);
                                appendLog("RESPOSTA " + responseCode + ": " + result);
                            }
                        }
                    });

                } catch (final Exception e) {
                    mainHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            txtStatus.setText("Erro de conexão: " + e.getMessage());
                            txtStatus.setBackgroundColor(0xFFFFCDD2);
                            appendLog("ERRO DE CONEXÃO: " + e.getMessage());
                        }
                    });
                } finally {
                    if (conn != null) conn.disconnect();
                }
            }
        });
    }

    private void testarConexaoServidor() {
        final String ip = edtPCIp.getText().toString().trim();
        final String port = edtPort.getText().toString().trim();

        appendLog("Testando comunicação com: http://" + ip + ":" + port + "...");
        txtStatus.setText("Testando conexão com o PC...");

        executorService.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    URL url = new URL("http://" + ip + ":" + port + "/");
                    HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                    conn.setConnectTimeout(3000);
                    conn.connect();
                    final int code = conn.getResponseCode();
                    conn.disconnect();

                    mainHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            txtStatus.setText("Conexão OK! Servidor respondeu (Código " + code + ")");
                            txtStatus.setBackgroundColor(0xFFC8E6C9);
                            appendLog("CONEXÃO OK: Servidor VCL ativo e acessível na porta " + port);
                            Toast.makeText(MainActivity.this, "Conexão com PC OK!", Toast.LENGTH_SHORT).show();
                        }
                    });
                } catch (final Exception e) {
                    mainHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            txtStatus.setText("Falha de conexão: " + e.getMessage());
                            txtStatus.setBackgroundColor(0xFFFFCDD2);
                            appendLog("FALHA DE REDE: Não foi possível alcançar o PC: " + e.getMessage());
                        }
                    });
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
