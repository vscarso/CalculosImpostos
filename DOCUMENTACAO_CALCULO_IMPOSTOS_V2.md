# 📘 Documentação: Classe TCalculadoraFiscal

> **Localização do Arquivo:** `Services\Unit_CalculoImpostos.pas`

Esta documentação serve como guia de referência para a utilização da classe `TCalculadoraFiscal`, responsável por centralizar a lógica tributária do emissor de NF-e, incluindo as novas regras da **Reforma Tributária (IBS/CBS/IS)**.

---

## 🚀 Como Usar (Guia Rápido)

Para realizar um cálculo, siga este fluxo de 4 passos simples:

1.  **Instancie** a classe.
2.  **Configure** o item (Valores e Quantidades).
3.  **Defina as Regras** (Regime, CST, Alíquotas).
4.  **Execute** `.Calcular` e leia o `.Resultado`.

### 📝 Exemplo de Código

```pascal
uses Unit_CalculoImpostos;

var
  Calc: TCalculadoraFiscal;
begin
  Calc := TCalculadoraFiscal.Create;
  try
    // -------------------------------------------------------
    // 📦 1. DADOS DO ITEM (Entradas Básicas)
    // -------------------------------------------------------
    Calc.ValorProduto        := 1000.00;
    Calc.Quantidade          := 1;
    Calc.ValorFrete          := 50.00;
    Calc.ValorDesconto       := 10.00; // Desconto incondicional

    // -------------------------------------------------------
    // ⚙️ 2. PERFIL DO EMITENTE & PRODUTO
    // -------------------------------------------------------
    Calc.Regime     := rtRegimeNormal;   // ou rtSimplesNacional
    Calc.Origem     := omNacional;       // Origem 0
    Calc.CST_CSOSN  := '10';             // CST 10 (ICMS ST)

    // -------------------------------------------------------
    // 💰 3. ALÍQUOTAS (Sistema Atual)
    // -------------------------------------------------------
    Calc.AliquotaICMS        := 18.00;   // 18%
    Calc.AliquotaIPI         := 5.00;    // 5%
    Calc.AliquotaPIS         := 1.65;
    Calc.AliquotaCOFINS      := 7.60;

    // 🔄 Substituição Tributária (ST)
    Calc.MVA                 := 40.00;   // Margem de Valor Agregado
    Calc.AliquotaInternaST   := 18.00;   // Alíquota destino
    
    // -------------------------------------------------------
    // 🆕 4. REFORMA TRIBUTÁRIA (IBS / CBS / IS)
    // -------------------------------------------------------
    Calc.AliquotaIBS         := 17.00;   // Imposto sobre Bens e Serviços
    Calc.AliquotaCBS         := 9.00;    // Contribuição sobre Bens e Serviços
    Calc.AliquotaIS          := 0.00;    // Imposto Seletivo ("Pecado")

    // -------------------------------------------------------
    // 🌍 5. DIFAL / FCP / DESONERAÇÃO (Avançado)
    // -------------------------------------------------------
    // DIFAL (Venda Interestadual Consumidor Final)
    Calc.AliquotaICMSInter   := 12.00;   // Interestadual (4, 7 ou 12)
    Calc.AliquotaICMSIntra   := 18.00;   // Destino
    Calc.AliquotaFCPDest     := 2.00;    // Fundo Pobreza Destino

    // Diferimento (CST 51)
    Calc.AliquotaDiferimento := 33.33;   // % do imposto que será diferido

    // -------------------------------------------------------
    // 🏭 6. IPI / PIS / COFINS (Por Situação Tributária)
    // -------------------------------------------------------
    Calc.CST_IPI     := '50';    // Saída Tributada
    Calc.CST_PIS     := '01';    // Operação Tributável Base Cheia
    Calc.CST_COFINS  := '01';
    
    // Exemplo PIS/COFINS por Quantidade (CST 03)
    // Calc.CST_PIS     := '03';
    // Calc.ValorUnidPIS := 1.50; // R$ 1,50 por unidade

    // -------------------------------------------------------
    // ✅ 7. EXECUTAR & LER
    // -------------------------------------------------------
    Calc.Calcular;

    // Lendo os valores calculados:
    ShowMessage('Base ICMS: ' + CurrToStr(Calc.Resultado.vBC_ICMS));
    ShowMessage('DIFAL Destino: ' + CurrToStr(Calc.Resultado.vICMS_UF_Dest));
    ShowMessage('Valor IPI: ' + CurrToStr(Calc.Resultado.vIPI));
    ShowMessage('Valor IBS: ' + CurrToStr(Calc.Resultado.vIBS));
    
  finally
    Calc.Free;
  end;
end;
```

---

## 🔑 Propriedades Importantes

Aqui estão as propriedades que você **precisa** preencher para garantir o cálculo correto.

### 📦 Entradas (Valores Monetários)
| Propriedade | Tipo | Obrigatório? | Descrição |
| :--- | :--- | :---: | :--- |
| `ValorProduto` | `Currency` | 🔴 **SIM** | Valor total bruto dos produtos. |
| `Quantidade` | `Double` | 🔴 **SIM** | Quantidade comercializada. |
| `ValorFrete` | `Currency` | ⚪ Opcional | Soma-se à base de cálculo. |
| `ValorSeguro` | `Currency` | ⚪ Opcional | Soma-se à base de cálculo. |
| `ValorDesconto` | `Currency` | ⚪ Opcional | Deduz-se da base de cálculo. |
| `ValorOutrasDespesas`| `Currency` | ⚪ Opcional | Soma-se à base de cálculo. |

### ⚙️ Configuração Fiscal
| Propriedade | Descrição Importante |
| :--- | :--- |
| `Regime` | Define se calcula como **Normal** (CST) ou **Simples** (CSOSN). <br> Valores: `rtRegimeNormal`, `rtSimplesNacional` |
| `CST_CSOSN` | **CRÍTICO:** Define qual fórmula usar. <br> Ex: `'00'` (Tributado Integral), `'10'` (Com ST), `'101'` (Simples c/ Crédito). |
| `Origem` | Origem da Mercadoria (`omNacional`, `omEstrangeira...`). |

### 🏭 IPI / PIS / COFINS (Situação Tributária)
| Propriedade | Descrição |
| :--- | :--- |
| `CST_IPI` | Código da Situação Tributária do IPI (Ex: '50' Tributado, '51' Isento). |
| `CST_PIS` | CST do PIS (Ex: '01' Tributável, '03' Por Qtde, '06' Alíquota Zero). |
| `CST_COFINS` | CST da COFINS (Segue a mesma lógica do PIS). |
| `ValorUnidIPI` | Valor em Reais por unidade (Pauta) para cálculo específico. |
| `ValorUnidPIS` | Valor em Reais por unidade para PIS (CST 03). |
| `ValorUnidCOFINS`| Valor em Reais por unidade para COFINS (CST 03). |

### 🌍 Configurações Avançadas (DIFAL / Desoneração / Diferimento)
| Propriedade | Descrição |
| :--- | :--- |
| `AliquotaICMSInter` | Alíquota Interestadual (4%, 7% ou 12%) para cálculo do DIFAL. |
| `AliquotaICMSIntra` | Alíquota Interna do estado de destino para cálculo do DIFAL. |
| `AliquotaFCPDest` | Alíquota do Fundo de Combate à Pobreza no estado de destino. |
| `AliquotaDiferimento` | Percentual do imposto que será diferido (CST 51). Ex: 100% ou 33.33%. |
| `MotivoDesoneracao` | Código do motivo da desoneração do ICMS (Ex: 7=SUFRAMA, 9=Outros). |

---

## 👨‍💻 Autor e Créditos

**Desenvolvido por:** Vitor Scarso  
**GitHub:** [github/vscarso](https://github.com/vscarso)  

Esta classe foi projetada para ser modular e independente, facilitando a integração em projetos existentes sem a necessidade de refatoração profunda.
