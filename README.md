# 📘 Manual da Calculadora Fiscal (NFe / NFCe)

> **Autor:** Vitor Scarso  
> **Versão:** 1.0  
> **Data:** 24/12/2025

---

## 🎯 O que é isso?

Esta é uma unidade inteligente (`Unit_CalculoImpostos`) projetada para **facilitar** a vida do desenvolvedor Delphi/Lazarus. Ela centraliza todas as regras chatas e complexas de tributação (ICMS, ST, IPI, PIS, COFINS e a nova **Reforma Tributária**) em uma única classe fácil de usar.

Você pode usá-la de duas formas:
1. 🧮 **Calculadora de Bolso:** Para fazer contas rápidas e isoladas.
2. 📝 **Emissão de Notas:** Para calcular todos os impostos de um item e preencher o componente ACBr.

---

## 🚀 1. Modo "Calculadora de Bolso" (Cálculos Rápidos)

Às vezes você só quer saber quanto é o **IBS** de um valor, ou qual a **Base Reduzida** de um produto, sem precisar criar uma Nota Fiscal inteira. Use os métodos isolados!

### Tabela de Métodos Disponíveis

| O que você quer calcular? | Método para chamar | Exemplo |
| :--- | :--- | :--- |
| **Imposto Simples** | `CalcularValorImposto` | 18% de R$ 100,00 = R$ 18,00 |
| **Base Reduzida** | `CalcularBaseReduzida` | Reduzir 20% de R$ 1.000,00 = R$ 800,00 |
| **IBS Estadual** | `CalcularValorIBS_UF` | IBS UF da Reforma Tributária |
| **IBS Municipal** | `CalcularValorIBS_Mun` | IBS Mun da Reforma Tributária |
| **CBS** | `CalcularValorCBS` | CBS Federal |
| **Imposto Seletivo** | `CalcularValorIS` | Imposto do "Pecado" |

### 💡 Exemplo Prático

```pascal
var
  Calc: TCalculadoraFiscal;
  ValorIBS, BaseReduzida: Currency;
begin
  Calc := TCalculadoraFiscal.Create;
  try
    // 1. Quero saber quanto é 17% de IBS sobre R$ 500,00
    ValorIBS := Calc.CalcularValorIBS_UF(500.00, 17.00);
    ShowMessage('O valor do IBS é: ' + CurrToStr(ValorIBS));

    // 2. Quero aplicar uma redução de 60% na base de R$ 1.000,00
    BaseReduzida := Calc.CalcularBaseReduzida(1000.00, 60.00);
    ShowMessage('A base tributável é apenas: ' + CurrToStr(BaseReduzida));
  finally
    Calc.Free;
  end;
end;
```

---

## 🔌 2. Integrando com o ACBr (O Pulo do Gato)

Esta classe foi feita pensando em preencher o componente **ACBrNFe**. Primeiro você calcula, depois você joga os valores para o componente.

### Exemplo de Uso Real

```pascal
var
  Calc: TCalculadoraFiscal;
  Prod: TDetCollectionItem; // Item do ACBr
begin
  // 1. Configurar a Calculadora
  Calc := TCalculadoraFiscal.Create;
  try
    // Dados do Produto
    Calc.ValorProduto := 1000.00;
    Calc.ValorFrete   := 50.00;
    
    // Configuração Fiscal (Ex: Venda para Consumidor - CST 00)
    Calc.Regime       := rtRegimeNormal;
    Calc.CST_CSOSN    := '00';
    Calc.AliquotaICMS := 18.00;
    
    // === CALCULAR TUDO AGORA ===
    Calc.Calcular;
    
    // 2. Preencher o ACBr
    // Supondo que você já adicionou o item no componente ACBr
    with Prod.Imposto.ICMS do 
    begin
      CST      := cst00; 
      orig     := oeNacional;
      modBC    := dbiValorOperacao;
      
      // Aqui entram os valores calculados pela nossa classe!
      vBC      := Calc.Resultado.vBC_ICMS;
      pICMS    := Calc.Resultado.pICMS;
      vICMS    := Calc.Resultado.vICMS;
    end;
    
    // Se tiver PIS/COFINS também já está pronto:
    with Prod.Imposto.PIS do
    begin
      CST  := pis01;
      vBC  := Calc.Resultado.vBC_PIS;
      pPIS := Calc.Resultado.pPIS;
      vPIS := Calc.Resultado.vPIS;
    end;
    
  finally
    Calc.Free;
  end;
end;
```

---

## ⚖️ 3. Reforma Tributária (IBS e CBS)

A classe já está preparada para o futuro! Ela entende os novos códigos de situação tributária (CST) da Reforma.

### Como funciona?

Se você informar um CST de **Isenção** (ex: `04`), a calculadora vai zerar o imposto automaticamente, mesmo que você tenha informado uma alíquota. Isso evita erros de cálculo!

```pascal
  // Exemplo: Produto Isento na Reforma
  Calc.CST_IBS := '04'; // Operação Isenta
  Calc.AliquotaIBS_UF := 12.00; 
  
  Calc.CalcularReformaTributaria;
  
  // O resultado será ZERO, pois o CST manda isentar.
  // Calc.Resultado.vIBS_UF -> 0.00
```

---

## ✨ Dicas de Ouro

1. **Auto Ajuste de MVA**: Se você estiver calculando ST interestadual, ative a propriedade `AutoAjustarMVA := True`. A classe fará a fórmula complexa do ajuste automaticamente.
2. **DIFAL**: A classe também calcula o DIFAL (Partilha de ICMS) para vendas interestaduais para consumidor final.
3. **Desoneração**: Se você informar `% Redução` e `Motivo Desoneração`, ela calcula automaticamente o "ICMS Desonerado" (aquele que é abatido do valor da nota).

---

> **Dúvidas?** Consulte o código fonte em `Unit_CalculoImpostos.pas`, ele está todo comentado!

