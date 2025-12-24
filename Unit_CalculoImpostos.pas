unit Unit_CalculoImpostos;

{
  --------------------------------------------------------------------------------
  Unit de Cálculo de Impostos - NF-e / NFC-e
  --------------------------------------------------------------------------------
  Autor: Vitor Scarso
  GitHub: github/vscarso
  Data: 24/12/2025
  Descrição:
    Classe responsável por centralizar toda a lógica de cálculo de tributos
    (ICMS, IPI, PIS, COFINS, ISSQN) e regras da Reforma Tributária (IBS, CBS, IS).
  --------------------------------------------------------------------------------
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;

type
  // Enum para definir o Regime Tributário do Emitente
  TRegimeTributario = (rtSimplesNacional, rtRegimeNormal);

  // Enum para Origem da Mercadoria
  TOrigemMercadoria = (
    omNacional = 0,
    omEstrangeiraImportacaoDireta = 1,
    omEstrangeiraAdquiridaNoMercadoInterno = 2,
    omNacionalConteudoImportacaoSuperior40 = 3,
    omNacionalProducaoConformeProcessoBasico = 4,
    omNacionalConteudoImportacaoInferior40 = 5,
    omEstrangeiraImportacaoDiretaSemSimilar = 6,
    omEstrangeiraAdquiridaNoMercadoInternoSemSimilar = 7,
    omNacionalConteudoImportacaoSuperior70 = 8
  );

  { TResultadoImpostos
    Record para armazenar os resultados dos cálculos de forma estruturada.
    Isso facilita a atribuição em lote depois. }
  TResultadoImpostos = record
    // ICMS Próprio
    vBC_ICMS: Currency;
    pICMS: Double;
    vICMS: Currency;
    modBC: Integer; // 0=Margem Valor Agregado, 3=Valor Operação, etc.
    pRedBC: Double; // Percentual de Redução de Base

    // ICMS Diferido (CST 51)
    vICMSOp: Currency;    // Valor do ICMS da Operação
    pDif: Double;         // Percentual do Diferimento
    vICMSDif: Currency;   // Valor do ICMS Diferido

    // ICMS Desonerado
    vICMSDeson: Currency;
    motDesICMS: Integer;  // Motivo da desoneração

    // ICMS ST (Substituição Tributária)
    vBC_ST: Currency;
    pICMS_ST: Double;
    vICMS_ST: Currency;
    pMVA_ST: Double;
    pRedBC_ST: Double;

    // IPI
    vBC_IPI: Currency;
    pIPI: Double;
    vIPI: Currency;

    // PIS
    vBC_PIS: Currency;
    pPIS: Double;
    vPIS: Currency;

    // COFINS
    vBC_COFINS: Currency;
    pCOFINS: Double;
    vCOFINS: Currency;

    // DIFAL (Partilha ICMS Interestadual)
    vBC_UF_Dest: Currency;
    vBC_FCP_UF_Dest: Currency;
    pFCP_UF_Dest: Double;
    vFCP_UF_Dest: Currency;
    pICMS_UF_Dest: Double;
    pICMS_Inter: Double;
    pICMS_Partilha: Double;
    vICMS_UF_Dest: Currency;
    vICMS_UF_Remet: Currency;

    // Simples Nacional (Crédito)
    pCredSN: Double;
    vCredICMSSN: Currency;
    
    // FCP (Fundo de Combate à Pobreza)
    vBC_FCP: Currency;
    pFCP: Double;
    vFCP: Currency;
    vBC_FCPST: Currency;
    pFCPST: Double;
    vFCPST: Currency;

    // Reforma Tributária (IBS/CBS/IS)
    // IBS
    vBC_IBS: Currency;
    pIBS: Double;
    vIBS: Currency;
    
    // CBS
    vBC_CBS: Currency;
    pCBS: Double;
    vCBS: Currency;
    
    // Imposto Seletivo (IS)
    vBC_IS: Currency;
    pIS: Double;
    vIS: Currency;

    // Detalhamento IBS (Reforma Tributária)
    vIBS_UF: Currency;      // Parte Estadual
    vIBS_Mun: Currency;     // Parte Municipal
    pIBS_UF: Double;        // Alíquota Estadual
    pIBS_Mun: Double;       // Alíquota Municipal

    // Crédito Presumido / Benefícios Fiscais (Reforma)
    vCredPresumidoIBS: Currency;
    vCredPresumidoCBS: Currency;
    pCredPresumidoIBS: Double;
    pCredPresumidoCBS: Double;
    
    // Outros ajustes da Reforma (Valores manuais ou calculados)
    vEstornoCreditoIBS: Currency;
    vEstornoCreditoCBS: Currency;
  end;

  { TCalculadoraFiscal
    Classe responsável por orquestrar os cálculos tributários do item. }
  TCalculadoraFiscal = class
  private
    // Entradas
    FValorProduto: Currency;
    FQuantidade: Double;
    FValorFrete: Currency;
    FValorSeguro: Currency;
    FValorOutrasDespesas: Currency;
    FValorDesconto: Currency;

    // Configuração Fiscal
    FRegime: TRegimeTributario;
    FCST_CSOSN: String; // Ex: '00', '101', '500'
    FOrigem: TOrigemMercadoria;
    
    // Reforma Tributária: Novo Código de Tributação IBS/CBS
    // O padrão será usar CST específico ou lógica separada. A NT 2025.002 define novos CSTs.
    // Vamos assumir que o usuário passará as alíquotas do IBS/CBS.
    FAliquotaIBS: Double;
    FAliquotaCBS: Double;
    FAliquotaIS: Double; // Imposto Seletivo
    
    // Split do IBS (Estadual e Municipal)
    FAliquotaIBS_UF: Double;
    FAliquotaIBS_Mun: Double;
    
    // Benefícios da Reforma
    FAliquotaCreditoPresumidoIBS: Double;
    FAliquotaCreditoPresumidoCBS: Double;

    // Alíquotas e Reduções
    FAliquotaICMS: Double;
    FReducaoBaseICMS: Double; // Em % (ex: 33.33)
    FAliquotaDiferimento: Double; // Para CST 51 (ex: 100% ou 33.33%)
    FMotivoDesoneracao: Integer; // Para CST 20, 30, 40, etc.
    
    // DIFAL
    FAliquotaICMSInter: Double; // Interestadual (4, 7 ou 12)
    FAliquotaICMSIntra: Double; // Interna Destino (ex: 18)
    FAliquotaFCPDest: Double;   // FCP no Destino
    
    FAliquotaIPI: Double;
    
    FAliquotaPIS: Double;
    FAliquotaCOFINS: Double;
    
    // Variáveis para ST
    FMVA: Double; // Margem de Valor Agregado
    FMVAOriginal: Double;
    FAutoAjustarMVA: Boolean;
    FAliquotaInternaST: Double; // Alíquota do destino
    FReducaoBaseST: Double;

    // Variáveis para Simples Nacional
    FAliquotaCreditoSN: Double; // Alíquota aplicável para crédito (CSOSN 101/201)

    // Variáveis para FCP
    FAliquotaFCP: Double;
    FAliquotaFCPST: Double;
    
    // CSTs Específicos (além do CST_CSOSN do ICMS)
    FCST_IPI: String;
    FCST_PIS: String;
    FCST_COFINS: String;
    
    // CSTs Reforma Tributária (Novos)
    FCST_IBS: String;
    FCST_CBS: String;
    FCST_IS: String;
    
    // Valores Específicos por Unidade (Pauta)
    FValorUnidIPI: Currency;
    FValorUnidPIS: Currency;
    FValorUnidCOFINS: Currency;

    // Resultado
    FResultado: TResultadoImpostos;

    procedure ZerarResultado;

    // Métodos internos de cálculo específicos
    procedure CalcularICMS_Normal;
    procedure CalcularICMS_ST;
    procedure CalcularICMS_Simples; // Para CSOSN
    procedure CalcularIPI;
    procedure CalcularPISCOFINS;
    procedure CalcularFCP;
    procedure CalcularDIFAL; // Novo método para Partilha

  public
    constructor Create;

    // Método principal
    procedure Calcular;
    
    // Método da Reforma (Tornado público para testes isolados e acesso granular)
    procedure CalcularReformaTributaria;
    
    // Métodos Auxiliares / Getters
    function GetValorTotalItem: Currency; // Prod + Frete + Seg + Outras - Desc

    // Métodos de Cálculo Isolados (Helpers)
    // Permitem realizar cálculos específicos sem depender do estado completo do objeto
    function CalcularBaseReduzida(const aBase: Currency; const aPercentualReducao: Double): Currency;
    function CalcularValorImposto(const aBase: Currency; const aAliquota: Double): Currency;
    
    // Wrappers Semânticos para Reforma Tributária (Cálculo Isolado)
    function CalcularValorIBS_UF(const aBase: Currency; const aAliquota: Double): Currency;
    function CalcularValorIBS_Mun(const aBase: Currency; const aAliquota: Double): Currency;
    function CalcularValorCBS(const aBase: Currency; const aAliquota: Double): Currency;
    function CalcularValorIS(const aBase: Currency; const aAliquota: Double): Currency;

    // Propriedades de Entrada
    property ValorProduto: Currency read FValorProduto write FValorProduto;
    property Quantidade: Double read FQuantidade write FQuantidade;
    property ValorFrete: Currency read FValorFrete write FValorFrete;
    property ValorSeguro: Currency read FValorSeguro write FValorSeguro;
    property ValorOutrasDespesas: Currency read FValorOutrasDespesas write FValorOutrasDespesas;
    property ValorDesconto: Currency read FValorDesconto write FValorDesconto;

    property Regime: TRegimeTributario read FRegime write FRegime;
    property CST_CSOSN: String read FCST_CSOSN write FCST_CSOSN;
    property Origem: TOrigemMercadoria read FOrigem write FOrigem;

    // Propriedades Reforma Tributária
    property AliquotaIBS: Double read FAliquotaIBS write FAliquotaIBS;
    property AliquotaCBS: Double read FAliquotaCBS write FAliquotaCBS;
    property AliquotaIS: Double read FAliquotaIS write FAliquotaIS;
    
    // Detalhamento Reforma
    property AliquotaIBS_UF: Double read FAliquotaIBS_UF write FAliquotaIBS_UF;
    property AliquotaIBS_Mun: Double read FAliquotaIBS_Mun write FAliquotaIBS_Mun;
    property AliquotaCreditoPresumidoIBS: Double read FAliquotaCreditoPresumidoIBS write FAliquotaCreditoPresumidoIBS;
    property AliquotaCreditoPresumidoCBS: Double read FAliquotaCreditoPresumidoCBS write FAliquotaCreditoPresumidoCBS;

    property AliquotaICMS: Double read FAliquotaICMS write FAliquotaICMS;
    property ReducaoBaseICMS: Double read FReducaoBaseICMS write FReducaoBaseICMS;
    property AliquotaDiferimento: Double read FAliquotaDiferimento write FAliquotaDiferimento;
    property MotivoDesoneracao: Integer read FMotivoDesoneracao write FMotivoDesoneracao;

    property AliquotaICMSInter: Double read FAliquotaICMSInter write FAliquotaICMSInter;
    property AliquotaICMSIntra: Double read FAliquotaICMSIntra write FAliquotaICMSIntra;
    property AliquotaFCPDest: Double read FAliquotaFCPDest write FAliquotaFCPDest;

    property AliquotaIPI: Double read FAliquotaIPI write FAliquotaIPI;
    property AliquotaPIS: Double read FAliquotaPIS write FAliquotaPIS;
    property AliquotaCOFINS: Double read FAliquotaCOFINS write FAliquotaCOFINS;

    property MVA: Double read FMVA write FMVA;
    property MVAOriginal: Double read FMVAOriginal write FMVAOriginal;
    property AutoAjustarMVA: Boolean read FAutoAjustarMVA write FAutoAjustarMVA;
    property AliquotaInternaST: Double read FAliquotaInternaST write FAliquotaInternaST;
    property ReducaoBaseST: Double read FReducaoBaseST write FReducaoBaseST;

    property AliquotaCreditoSN: Double read FAliquotaCreditoSN write FAliquotaCreditoSN;
    
    property AliquotaFCP: Double read FAliquotaFCP write FAliquotaFCP;
    property AliquotaFCPST: Double read FAliquotaFCPST write FAliquotaFCPST;

    property CST_IPI: String read FCST_IPI write FCST_IPI;
    property CST_PIS: String read FCST_PIS write FCST_PIS;
    property CST_COFINS: String read FCST_COFINS write FCST_COFINS;
    
    // CSTs Reforma
    property CST_IBS: String read FCST_IBS write FCST_IBS;
    property CST_CBS: String read FCST_CBS write FCST_CBS;
    property CST_IS: String read FCST_IS write FCST_IS;

    property ValorUnidIPI: Currency read FValorUnidIPI write FValorUnidIPI;
    property ValorUnidPIS: Currency read FValorUnidPIS write FValorUnidPIS;
    property ValorUnidCOFINS: Currency read FValorUnidCOFINS write FValorUnidCOFINS;

    // Acesso ao Resultado
    property Resultado: TResultadoImpostos read FResultado;
  end;

implementation

{ TCalculadoraFiscal }

constructor TCalculadoraFiscal.Create;
begin
  ZerarResultado;
  FRegime := rtRegimeNormal;
  FOrigem := omNacional;
  FQuantidade := 1;
end;

procedure TCalculadoraFiscal.ZerarResultado;
begin
  FillChar(FResultado, SizeOf(FResultado), 0);
  // Define padrões
  FResultado.modBC := 3; // 3 = Valor da Operação (padrão mais comum)
end;

function TCalculadoraFiscal.GetValorTotalItem: Currency;
begin
  // Base padrão: Valor do Produto + Despesas Acessórias - Desconto Incondicional
  Result := (FValorProduto + FValorFrete + FValorSeguro + FValorOutrasDespesas) - FValorDesconto;
  if Result < 0 then Result := 0;
end;

function TCalculadoraFiscal.CalcularBaseReduzida(const aBase: Currency; const aPercentualReducao: Double): Currency;
begin
  if aPercentualReducao > 0 then
    Result := aBase * (1 - (aPercentualReducao / 100))
  else
    Result := aBase;
end;

function TCalculadoraFiscal.CalcularValorImposto(const aBase: Currency; const aAliquota: Double): Currency;
begin
  if aAliquota > 0 then
    Result := RoundTo(aBase * (aAliquota / 100), -2)
  else
    Result := 0;
end;

function TCalculadoraFiscal.CalcularValorIBS_UF(const aBase: Currency; const aAliquota: Double): Currency;
begin
  Result := CalcularValorImposto(aBase, aAliquota);
end;

function TCalculadoraFiscal.CalcularValorIBS_Mun(const aBase: Currency; const aAliquota: Double): Currency;
begin
  Result := CalcularValorImposto(aBase, aAliquota);
end;

function TCalculadoraFiscal.CalcularValorCBS(const aBase: Currency; const aAliquota: Double): Currency;
begin
  Result := CalcularValorImposto(aBase, aAliquota);
end;

function TCalculadoraFiscal.CalcularValorIS(const aBase: Currency; const aAliquota: Double): Currency;
begin
  Result := CalcularValorImposto(aBase, aAliquota);
end;

procedure TCalculadoraFiscal.CalcularICMS_Normal;
var
  BaseCalc, BaseIntegral, ValorICMSIntegral: Currency;
begin
  BaseIntegral := GetValorTotalItem;
  
  // Aplica Redução de Base de Cálculo se houver (Usa helper)
  BaseCalc := CalcularBaseReduzida(BaseIntegral, FReducaoBaseICMS);

  FResultado.vBC_ICMS := BaseCalc;
  FResultado.pICMS := FAliquotaICMS;
  // Usa helper para cálculo do valor
  FResultado.vICMS := CalcularValorImposto(BaseCalc, FAliquotaICMS);
  
  // Cálculo de Desoneração (ICMS que deixou de ser pago devido à redução)
  if (FReducaoBaseICMS > 0) and (FMotivoDesoneracao > 0) then
  begin
    ValorICMSIntegral := CalcularValorImposto(BaseIntegral, FAliquotaICMS);
    FResultado.vICMSDeson := ValorICMSIntegral - FResultado.vICMS;
    FResultado.motDesICMS := FMotivoDesoneracao;
  end;
  
  // Cálculo de Diferimento (CST 51)
  if (FCST_CSOSN = '51') then
  begin
    FResultado.vICMSOp := FResultado.vICMS; // Valor da operação antes do diferimento
    FResultado.pDif := FAliquotaDiferimento;
    
    if FAliquotaDiferimento > 0 then
    begin
      FResultado.vICMSDif := CalcularValorImposto(FResultado.vICMSOp, FAliquotaDiferimento);
      FResultado.vICMS := FResultado.vICMSOp - FResultado.vICMSDif; // Valor devido é o que sobra
    end;
  end;
end;

procedure TCalculadoraFiscal.CalcularDIFAL;
var
  BaseDIFAL, DifAliquota: Double;
begin
  BaseDIFAL := GetValorTotalItem;
  
  // DIFAL = Base * (AlqIntra - AlqInter)
  // Assumindo partilha 100% destino (padrão atual)
  
  if FAliquotaICMSIntra > FAliquotaICMSInter then
  begin
    DifAliquota := FAliquotaICMSIntra - FAliquotaICMSInter;
    
    FResultado.vBC_UF_Dest := BaseDIFAL;
    FResultado.pICMS_UF_Dest := FAliquotaICMSIntra;
    FResultado.pICMS_Inter := FAliquotaICMSInter;
    FResultado.pICMS_Partilha := 100; // 100% para destino
    
    FResultado.vICMS_UF_Dest := RoundTo(BaseDIFAL * (DifAliquota / 100), -2);
    FResultado.vICMS_UF_Remet := 0; // Sem partilha para remetente atualmente
  end;
  
  // FCP Destino
  if FAliquotaFCPDest > 0 then
  begin
    FResultado.vBC_FCP_UF_Dest := BaseDIFAL;
    FResultado.pFCP_UF_Dest := FAliquotaFCPDest;
    FResultado.vFCP_UF_Dest := RoundTo(BaseDIFAL * (FAliquotaFCPDest / 100), -2);
  end;
end;

procedure TCalculadoraFiscal.CalcularICMS_ST;
var
  BaseST: Currency;
  ValorICMSProprio: Currency;
  Coeficiente: Double;
begin
  // 0. Ajuste de MVA (Se solicitado)
  // Fórmula: MVA Ajustada = [(1 + MVA_Orig) * (1 - Alq_Inter) / (1 - Alq_Intra)] - 1
  if FAutoAjustarMVA and (FMVAOriginal > 0) then
  begin
    // Valida se temos as alíquotas necessárias para o ajuste
    // Alíquota Interestadual (ICMS Próprio da operação) e Interna do Destino (ST)
    if (FAliquotaICMS > 0) and (FAliquotaInternaST > FAliquotaICMS) then
    begin
      Coeficiente := (1 + (FMVAOriginal / 100)) * (1 - (FAliquotaICMS / 100)) / (1 - (FAliquotaInternaST / 100));
      FMVA := RoundTo((Coeficiente - 1) * 100, -2); // Arredonda para 2 casas
    end
    else
    begin
      FMVA := FMVAOriginal; // Não ajusta se alíquota interna <= interestadual ou inválida
    end;
  end
  else if (FMVAOriginal > 0) and (FMVA = 0) then
  begin
    // Se passou MVA Original mas não pediu ajuste e não passou MVA efetiva, usa a Original
    FMVA := FMVAOriginal;
  end;

  // 1. Calcula o ICMS Próprio (usado para abater no ST)
  // Nota: Mesmo que o emitente seja Simples Nacional, para fins de cálculo de ST, 
  // muitas vezes usa-se a regra geral ou alíquotas interestaduais. 
  // Aqui assumimos a lógica padrão de débito/crédito.
  
  ValorICMSProprio := FResultado.vICMS; // Assume que CalcularICMS_Normal já rodou ou simula-se
  if (FRegime = rtSimplesNacional) and (ValorICMSProprio = 0) then
  begin
     // Se for simples, usa-se a alíquota interestadual para achar o "ICMS Próprio virtual" para abatimento
     // Isso depende da legislação estadual, mas é comum usar a alíquota cheia (ex: 12% ou 7%) apenas para dedução.
     // VOU USAR A ALIQUOTA INFORMADA NO CAMPO ICMS COMO SENDO A INTERESTADUAL
     ValorICMSProprio := GetValorTotalItem * (FAliquotaICMS / 100); 
  end;

  // 2. Base do ST = (ValorItem + IPI se incidir na base) * (1 + MVA)
  // *Nota: IPI compõe a base do ICMS ST se o produto for para consumo final ou se não for contribuinte.
  // Para simplificar, vamos usar a base padrão.
  
  BaseST := GetValorTotalItem + FResultado.vIPI; // Soma IPI na base do ST geralmente
  
  // Aplica MVA
  if FMVA > 0 then
    BaseST := BaseST * (1 + (FMVA / 100));
    
  // Aplica Redução na Base ST
  if FReducaoBaseST > 0 then
    BaseST := BaseST * (1 - (FReducaoBaseST / 100));

  FResultado.vBC_ST := BaseST;
  FResultado.pICMS_ST := FAliquotaInternaST;
  FResultado.pMVA_ST := FMVA;
  FResultado.pRedBC_ST := FReducaoBaseST;
  
  // Valor ST = (BaseST * AliquotaInterna) - ICMSProprio
  FResultado.vICMS_ST := RoundTo((BaseST * (FAliquotaInternaST / 100)) - ValorICMSProprio, -2);
  
  if FResultado.vICMS_ST < 0 then FResultado.vICMS_ST := 0;
end;

procedure TCalculadoraFiscal.CalcularICMS_Simples;
begin
  // CSOSN 101 - Tributada com permissão de crédito
  if (FCST_CSOSN = '101') or (FCST_CSOSN = '201') then
  begin
    FResultado.pCredSN := FAliquotaCreditoSN;
    FResultado.vCredICMSSN := RoundTo(GetValorTotalItem * (FAliquotaCreditoSN / 100), -2);
  end;

  // CSOSN 201, 202, 203, 900 - Pode ter ST
  if (FCST_CSOSN = '201') or (FCST_CSOSN = '202') or (FCST_CSOSN = '203') or (FCST_CSOSN = '900') then
  begin
    CalcularICMS_ST;
  end;
  
  // CSOSN 900 - Outros (Pode ter ICMS Próprio também)
  if FCST_CSOSN = '900' then
  begin
    CalcularICMS_Normal;
  end;
end;

procedure TCalculadoraFiscal.CalcularIPI;
var
  BaseIPI: Currency;
begin
  // Se CST não foi informado, mas tem alíquota, assume tributado (comportamento legado)
  if (FCST_IPI = '') and (FAliquotaIPI > 0) then FCST_IPI := '50';

  // CSTs de Saída Tributada: 50, 49, 99
  // CSTs de Entrada Tributada: 00, 49, 99
  if (FCST_IPI = '00') or (FCST_IPI = '49') or (FCST_IPI = '50') or (FCST_IPI = '99') then
  begin
    // Cálculo por Alíquota (Ad Valorem)
    if FAliquotaIPI > 0 then
    begin
      BaseIPI := GetValorTotalItem; // Geralmente Frete e Seguro entram na base do IPI
      FResultado.vBC_IPI := BaseIPI;
      FResultado.pIPI := FAliquotaIPI;
      FResultado.vIPI := RoundTo(BaseIPI * (FAliquotaIPI / 100), -2);
    end
    // Cálculo por Unidade (Pauta)
    else if FValorUnidIPI > 0 then
    begin
      FResultado.vBC_IPI := FQuantidade; // Base é a quantidade
      FResultado.vIPI := RoundTo(FQuantidade * FValorUnidIPI, -2);
      // pIPI fica zerado pois é valor fixo
    end;
  end
  else
  begin
    // Isento, Imune, Suspenso (01..05, 51..55)
    FResultado.vBC_IPI := 0;
    FResultado.pIPI := 0;
    FResultado.vIPI := 0;
  end;
end;

procedure TCalculadoraFiscal.CalcularPISCOFINS;
var
  BasePISCOFINS: Currency;
begin
  BasePISCOFINS := GetValorTotalItem;
  // *Importante: ICMS pode ser excluído da base do PIS/COFINS dependendo da decisão do STF ("Tese do Século")
  // Aqui faremos o cálculo padrão (Base Cheia), mas poderia haver uma flag para excluir o ICMS.

  // --- PIS ---
  // CSTs Tributáveis: 01, 02
  if (FCST_PIS = '01') or (FCST_PIS = '02') then
  begin
    FResultado.vBC_PIS := BasePISCOFINS;
    FResultado.pPIS := FAliquotaPIS;
    FResultado.vPIS := RoundTo(BasePISCOFINS * (FAliquotaPIS / 100), -2);
  end
  // CST Quantidade: 03
  else if (FCST_PIS = '03') then
  begin
    FResultado.vBC_PIS := FQuantidade;
    FResultado.vPIS := RoundTo(FQuantidade * FValorUnidPIS, -2);
  end
  // Outras Operações (pode ser tributado): 49..99
  else if (StrToIntDef(FCST_PIS, 0) >= 49) and (FAliquotaPIS > 0) then
  begin
    FResultado.vBC_PIS := BasePISCOFINS;
    FResultado.pPIS := FAliquotaPIS;
    FResultado.vPIS := RoundTo(BasePISCOFINS * (FAliquotaPIS / 100), -2);
  end
  else
  begin
    // Isento/Alíquota Zero (04, 05, 06, 07, 08, 09)
    FResultado.vBC_PIS := 0;
    FResultado.pPIS := 0;
    FResultado.vPIS := 0;
  end;

  // --- COFINS ---
  // CSTs Tributáveis: 01, 02
  if (FCST_COFINS = '01') or (FCST_COFINS = '02') then
  begin
    FResultado.vBC_COFINS := BasePISCOFINS;
    FResultado.pCOFINS := FAliquotaCOFINS;
    FResultado.vCOFINS := RoundTo(BasePISCOFINS * (FAliquotaCOFINS / 100), -2);
  end
  // CST Quantidade: 03
  else if (FCST_COFINS = '03') then
  begin
    FResultado.vBC_COFINS := FQuantidade;
    FResultado.vCOFINS := RoundTo(FQuantidade * FValorUnidCOFINS, -2);
  end
  // Outras Operações: 49..99
  else if (StrToIntDef(FCST_COFINS, 0) >= 49) and (FAliquotaCOFINS > 0) then
  begin
    FResultado.vBC_COFINS := BasePISCOFINS;
    FResultado.pCOFINS := FAliquotaCOFINS;
    FResultado.vCOFINS := RoundTo(BasePISCOFINS * (FAliquotaCOFINS / 100), -2);
  end
  else
  begin
    // Isento/Alíquota Zero
    FResultado.vBC_COFINS := 0;
    FResultado.pCOFINS := 0;
    FResultado.vCOFINS := 0;
  end;
end;

procedure TCalculadoraFiscal.CalcularFCP;
begin
  // FCP Normal
  if FAliquotaFCP > 0 then
  begin
    FResultado.vBC_FCP := FResultado.vBC_ICMS; // Geralmente segue a base do ICMS
    FResultado.pFCP := FAliquotaFCP;
    FResultado.vFCP := RoundTo(FResultado.vBC_FCP * (FAliquotaFCP / 100), -2);
  end;

  // FCP ST
  if FAliquotaFCPST > 0 then
  begin
    FResultado.vBC_FCPST := FResultado.vBC_ST;
    FResultado.pFCPST := FAliquotaFCPST;
    FResultado.vFCPST := RoundTo(FResultado.vBC_FCPST * (FAliquotaFCPST / 100), -2);
  end;
end;

procedure TCalculadoraFiscal.CalcularReformaTributaria;
var
  BaseCalculo: Currency;
  BaseCredPresumido: Currency;
  
  // Função auxiliar para verificar CST Tributado
  function IsCSTTributado(const aCST: String): Boolean;
  begin
    // Se vazio, assume tributado se tiver alíquota (comportamento padrão)
    if aCST = '' then Exit(True);
    
    // Lista de CSTs Tributados (Baseada em padrões de PIS/COFINS e futura NT)
    // 01: Operação Tributável com Alíquota Básica
    // 02: Operação Tributável com Alíquota Diferenciada
    // 50..66: Outras operações com direito a crédito
    Result := (aCST = '01') or (aCST = '02') or (StrToIntDef(aCST, 0) >= 50);
  end;
  
  // Função auxiliar para verificar CST Isento/Imune/Suspenso
  function IsCSTIsentoOuImune(const aCST: String): Boolean;
  begin
    // 04: Isenta
    // 05: Imune
    // 06: Suspensa
    // 40..49: Operações sem incidência
    Result := (aCST = '04') or (aCST = '05') or (aCST = '06') or ((StrToIntDef(aCST, 0) >= 40) and (StrToIntDef(aCST, 0) <= 49));
  end;
  
begin
  // Base de Cálculo Geral: Valor do Item + Despesas Acessórias - Descontos
  // IMPORTANTE: IBS e CBS incidem sobre o valor da operação "por fora", mas para fins
  // de preenchimento inicial nos documentos fiscais, a base geralmente segue o valor da operação.
  // O IBS e CBS NÃO integram a sua própria base de cálculo (cálculo "por fora").
  
  BaseCalculo := GetValorTotalItem;

  // --- Cálculo IBS (Imposto sobre Bens e Serviços) ---
  
  // Verifica Situação Tributária (CST)
  // Se for Isento/Imune e não tivermos regra específica de "Manter Base", zeramos tudo.
  if IsCSTIsentoOuImune(FCST_IBS) then
  begin
    FResultado.vBC_IBS := 0;
    FResultado.pIBS := 0;
    FResultado.vIBS := 0;
    FResultado.pIBS_UF := 0;
    FResultado.vIBS_UF := 0;
    FResultado.pIBS_Mun := 0;
    FResultado.vIBS_Mun := 0;
  end
  else
  // Se for Tributado ou Genérico (sem CST informado mas com alíquota)
  if IsCSTTributado(FCST_IBS) then
  begin
    // Se houver split informado (UF/Mun), calcula detalhado
    if (FAliquotaIBS_UF > 0) or (FAliquotaIBS_Mun > 0) then
    begin
      FResultado.vBC_IBS := BaseCalculo;
      
      // Parte Estadual
      if FAliquotaIBS_UF > 0 then
      begin
        FResultado.pIBS_UF := FAliquotaIBS_UF;
        FResultado.vIBS_UF := CalcularValorIBS_UF(BaseCalculo, FAliquotaIBS_UF);
      end;
      
      // Parte Municipal
      if FAliquotaIBS_Mun > 0 then
      begin
        FResultado.pIBS_Mun := FAliquotaIBS_Mun;
        FResultado.vIBS_Mun := CalcularValorIBS_Mun(BaseCalculo, FAliquotaIBS_Mun);
      end;
      
      // Totaliza IBS
      FResultado.vIBS := FResultado.vIBS_UF + FResultado.vIBS_Mun;
      // Recalcula alíquota total efetiva se não foi informada
      if FAliquotaIBS = 0 then
        FResultado.pIBS := FAliquotaIBS_UF + FAliquotaIBS_Mun
      else
        FResultado.pIBS := FAliquotaIBS;
    end
    else if FAliquotaIBS > 0 then
    begin
      // Cálculo Simples (sem split)
      FResultado.vBC_IBS := BaseCalculo;
      FResultado.pIBS := FAliquotaIBS;
      FResultado.vIBS := CalcularValorImposto(BaseCalculo, FAliquotaIBS);
    end;
  end;

  // --- Cálculo CBS (Contribuição sobre Bens e Serviços) ---
  
  if IsCSTIsentoOuImune(FCST_CBS) then
  begin
    FResultado.vBC_CBS := 0;
    FResultado.pCBS := 0;
    FResultado.vCBS := 0;
  end
  else if IsCSTTributado(FCST_CBS) and (FAliquotaCBS > 0) then
  begin
    FResultado.vBC_CBS := BaseCalculo;
    FResultado.pCBS := FAliquotaCBS;
    FResultado.vCBS := CalcularValorCBS(BaseCalculo, FAliquotaCBS);
  end;
  
  // --- Cálculo de Crédito Presumido (Reforma) ---
  // Geralmente vinculado a CSTs específicos, mas vamos manter a lógica de alíquota > 0 por enquanto
  if (FAliquotaCreditoPresumidoIBS > 0) or (FAliquotaCreditoPresumidoCBS > 0) then
  begin
    BaseCredPresumido := BaseCalculo; // Assume mesma base, salvo regra específica
    
    if FAliquotaCreditoPresumidoIBS > 0 then
    begin
      FResultado.pCredPresumidoIBS := FAliquotaCreditoPresumidoIBS;
      FResultado.vCredPresumidoIBS := CalcularValorImposto(BaseCredPresumido, FAliquotaCreditoPresumidoIBS);
    end;
    
    if FAliquotaCreditoPresumidoCBS > 0 then
    begin
      FResultado.pCredPresumidoCBS := FAliquotaCreditoPresumidoCBS;
      FResultado.vCredPresumidoCBS := CalcularValorImposto(BaseCredPresumido, FAliquotaCreditoPresumidoCBS);
    end;
  end;

  // --- Cálculo IS (Imposto Seletivo) ---
  if IsCSTIsentoOuImune(FCST_IS) then
  begin
    FResultado.vBC_IS := 0;
    FResultado.pIS := 0;
    FResultado.vIS := 0;
  end
  else if (FAliquotaIS > 0) and IsCSTTributado(FCST_IS) then
  begin
    FResultado.vBC_IS := BaseCalculo;
    FResultado.pIS := FAliquotaIS;
    FResultado.vIS := CalcularValorIS(BaseCalculo, FAliquotaIS);
  end;
end;

procedure TCalculadoraFiscal.Calcular;
begin
  ZerarResultado;

  // 1. Reforma Tributária (IBS/CBS/IS)
  // Calculamos primeiro pois o IS pode vir a compor a base de outros tributos no futuro.
  CalcularReformaTributaria;

  // 2. Calcula IPI (pois pode compor base de outros impostos)
  // Agora considera CSTs específicos
  CalcularIPI;

  // 3. Calcula ICMS baseado no Regime e CST/CSOSN
  if FRegime = rtRegimeNormal then
  begin
    // CSTs do Regime Normal
    // 00 - Tributada integralmente
    // 20 - Com redução de base
    // 10, 30, 70 - Com ST
    // 40, 41, 50 - Isenta/Não tributada
    // 51 - Diferimento
    // 90 - Outros
    
    if (FCST_CSOSN = '00') or (FCST_CSOSN = '20') or (FCST_CSOSN = '90') or (FCST_CSOSN = '10') or (FCST_CSOSN = '70') or (FCST_CSOSN = '51') then
      CalcularICMS_Normal;
      
    if (FCST_CSOSN = '10') or (FCST_CSOSN = '30') or (FCST_CSOSN = '70') or (FCST_CSOSN = '90') or (FCST_CSOSN = '201') or (FCST_CSOSN = '202') or (FCST_CSOSN = '203') then
      CalcularICMS_ST;
  end
  else // Simples Nacional
  begin
    CalcularICMS_Simples;
  end;

  // 3. Calcula PIS e COFINS
  // Verifica CST de PIS/COFINS dentro do método
  CalcularPISCOFINS;

  // 4. Calcula FCP
  CalcularFCP;
  
  // 5. Calcula DIFAL (Se houver alíquotas configuradas)
  if (FAliquotaICMSIntra > 0) and (FAliquotaICMSInter > 0) then
    CalcularDIFAL;
end;

end.
