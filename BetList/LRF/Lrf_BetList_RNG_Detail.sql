/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_RNG_Detail]
	@AgentList	VARCHAR(MAX),
	@CustId		INT,
	@RefNo		BIGINT,
	@TransType	TINYINT	= 0
AS

/*
	Created: Kos@20150921
	Task: Get ticket detail from table bettransRnG (Microgaming RNG Game)
	DB: DBEXT.bodb02
	Original:
	Revisions:
		- 20150924@Kos: Add column BetCheck to return TranId3rd for showing ticket result
		- 20151029@Kos: Change SportType of Microgaming RNG Casino
		- 20151223@Kos: Support RNG Casino Single Wallet and use SportBettypeMatrix [Redmine: #48958]
		- 20160406@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160530@Kos: Add ORDER BY statement to correct ticket order [Redmine: #58448]
		- 20160727@Kos: Include Void/Rejected detail tickets view drilldown WON/LOSE/DRAW summary tickets
					- Change to use inline function for SportBetTypeMatrix
		- 20161111@Kos: Support Fishing World [#Redmine: 66737]
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20180514@Kos: Return ExchangeId instead of CurrencyCode [#Redmine: 94845]
		- 20180525@Kos: Support Pragmatic Casino [#Redmine: 92318]
		- 20190321@Kos: Support Pragmatic Promotion Prize [#Redmine: 109471]
		- 20190401@Kos: Don't support Microgaming RNG Casino anymore [#Redmine: 107704]

	Parameters:
		- @TransType
			+ 0 : All (DRAW/WON/LOSE/Reject/Void/Refund/Running/Waiting)
			+ 1 : DRAW/WON/LOSE/Void/Reject/Refund
			+ 2 : Reject/Void
			+ 3 : Running/Waiting
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH

	-- Get SportBetTypeMatrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Support Microgaming RNG Casino, RNG Casino Single Wallet, Macau Games, Fishing World, Pragmatic Casino
	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (22, 24, 32)
		OR (ProductID = 6 AND SubProduct <> '')

	DECLARE @tmpStatus TABLE (statusId TINYINT)

	IF @TransType = 0
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 101 UNION ALL
		SELECT 102 UNION ALL
		SELECT 103 UNION ALL
		SELECT 0 UNION ALL
		SELECT 1
	END
	ELSE IF @TransType = 1
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 101 UNION ALL
		SELECT 102 UNION ALL
		SELECT 103
	END
	ELSE IF @TransType = 2
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 101 UNION ALL
		SELECT 102
	END 
	ELSE IF @TransType = 3
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 0 UNION ALL
		SELECT 1
	END

	DECLARE @tmpBettransRnG TABLE (
		TransId			BIGINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		Status			VARCHAR(10),
		StatusId		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Ip				NVARCHAR(15),
		TransDesc		NVARCHAR(1000),
		BetCheck		VARCHAR(64),
		MatchCode		VARCHAR(1000)
	)

	IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO @tmpBettransRnG
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			CASE
				WHEN brng.statusID IN (0, 1) THEN 0
				ELSE (brng.winlost - brng.actual_stake)
			END AS WinLost,
			CASE
				WHEN brng.statusID IN (0, 1) THEN 0
				ELSE - (brng.winlost - brng.actual_stake)
			END AS LicenseeWL,
			CASE
				WHEN brng.statusID IN (0, 1) THEN 0
				ELSE brng.comm
			END AS Comm,
			brng.playercomm,
			brng.ip,
			brng.transdesc,
			brng.TranId3rd AS BetCheck,
			CASE
				WHEN sbt.productID IN (24, 32) THEN brng.Additional
				ELSE ''
			END AS MatchCode
		FROM dbo.bettransRnG AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId 
			AND brng.RefNo = @RefNo
			AND brng.statusID IN (SELECT statusId FROM @tmpStatus)
	END
	ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO @tmpBettransRnG
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			CASE
				WHEN brng.statusID IN (0, 1) THEN 0
				ELSE (brng.winlost - brng.actual_stake)
			END AS WinLost,
			CASE
				WHEN brng.statusID IN (0, 1) THEN 0
				ELSE - (brng.winlost - brng.actual_stake)
			END AS LicenseeWL,
			CASE
				WHEN brng.statusID IN (0, 1) THEN 0
				ELSE brng.comm
			END AS Comm,
			brng.playercomm,
			brng.ip,
			brng.transdesc,
			brng.TranId3rd AS BetCheck,
			CASE
				WHEN sbt.productID IN (24, 32) THEN brng.Additional
				ELSE ''
			END AS MatchCode
		FROM dbo.bettransRnG14 AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId AND brng.RefNo = @RefNo
	END
	ELSE IF EXISTS ( SELECT 1 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO @tmpBettransRnG
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			CASE
				WHEN brng.statusID IN (0, 1) THEN 0
				ELSE (brng.winlost - brng.actual_stake)
			END AS WinLost,
			CASE
				WHEN brng.statusID IN (0, 1) THEN 0
				ELSE - (brng.winlost - brng.actual_stake)
			END AS LicenseeWL,
			CASE
				WHEN brng.statusID IN (0, 1) THEN 0
				ELSE brng.comm
			END AS Comm,
			brng.playercomm,
			brng.ip,
			brng.transdesc,
			brng.TranId3rd AS BetCheck,
			CASE
				WHEN sbt.productID IN (24, 32) THEN brng.Additional
				ELSE ''
			END AS MatchCode
		FROM DBARC.bodb_Archive.dbo.bettransRnG_bk AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId AND brng.RefNo = @RefNo
	END

	-- get currency (for security)
	DECLARE @Currency	INT

	SELECT @Currency = c.currency
	FROM dbo.custinfo AS c WITH (NOLOCK)
	WHERE c.custid = @CustId
		AND c.currency IN (SELECT DISTINCT Currency FROM @TempAg)

	-- get from date - to date
	DECLARE @Fromdate DATETIME
	DECLARE @Todate DATETIME

	SELECT @Fromdate = MIN(WinLostDate),
		@Todate = MAX(WinLostDate)
	FROM @tmpBettransRnG

	SELECT
		b.*,
		@Currency AS CurrencyId,
		CAST(b.Stake * e.USD AS MONEY) AS StakeUSD,
		CAST(b.Stake * e.EUR AS MONEY) AS StakeEUR,
		CAST(b.Stake * e.MYR AS MONEY) AS StakeMYR,
		CAST(b.Stake * e.GBP AS MONEY) AS StakeGBP,
		CAST(b.WinLost * e.USD AS MONEY) AS WinLostUSD,
		CAST(b.WinLost * e.EUR AS MONEY) AS WinLostEUR,
		CAST(b.WinLost * e.MYR AS MONEY) AS WinLostMYR,
		CAST(b.WinLost * e.GBP AS MONEY) AS WinLostGBP,
		CAST(b.LicenseeWL * e.USD AS MONEY) AS LicenseeWLUSD,
		CAST(b.LicenseeWL * e.EUR AS MONEY) AS LicenseeWLEUR,
		CAST(b.LicenseeWL * e.MYR AS MONEY) AS LicenseeWLMYR,
		CAST(b.LicenseeWL * e.GBP AS MONEY) AS LicenseeWLGBP,
		CAST(b.Comm * e.USD AS MONEY) AS CommUSD,
		CAST(b.Comm * e.EUR AS MONEY) AS CommEUR,
		CAST(b.Comm * e.MYR AS MONEY) AS CommMYR,
		CAST(b.Comm * e.GBP AS MONEY) AS CommGBP,
		CAST(b.PlayerComm * e.USD AS MONEY) AS PlayerCommUSD,
		CAST(b.PlayerComm * e.EUR AS MONEY) AS PlayerCommEUR,
		CAST(b.PlayerComm * e.MYR AS MONEY) AS PlayerCommMYR,
		CAST(b.PlayerComm * e.GBP AS MONEY) AS PlayerCommGBP
	FROM @tmpBettransRnG AS b
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)) AS e
			ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = @Currency
	ORDER BY b.TransId ASC
END
GO



GRANT EXECUTE ON [dbo].[Lrf_BetList_RNG_Detail] TO [bodbLicenseeNet] AS [dbo]
GO
