/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_LC_Detail]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@RefNo			BIGINT,
	@TransType		TINYINT	= 0,
	@BaseCurrency	VARCHAR(10)
AS

/*
	Created: Kos@20150923
	Task : Get ticket detail from table betransLC (AG Casino)
	DB: DBEXT.bodb02
	Original:
	Revisions:
		- 20160530@Kos: Add ORDER BY statement to correct ticket order [Redmine: #58448]
		- 20160727@Kos: Include Void/Rejected detail tickets view drilldown WON/LOSE/DRAW summary tickets
					- Change to use inline function for SportBetTypeMatrix
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20190524@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
		- 20200427@Kos: Support Sexy Gaming [Redmine: #130859]

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
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH

	-- Get SportBetTypeMatrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Support AG Casino Single Wallet, AllBet
	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (11, 21, 45)

	DECLARE @tmpStatus TABLE (StatusId TINYINT)

	IF @TransType = 0
	BEGIN
		INSERT INTO @tmpStatus (StatusId)
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
		INSERT INTO @tmpStatus (StatusId)
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 101 UNION ALL
		SELECT 102 UNION ALL
		SELECT 103
	END
	ELSE IF @TransType = 2
	BEGIN
		INSERT INTO @tmpStatus (StatusId)
		SELECT 101 UNION ALL
		SELECT 102
	END 
	ELSE IF @TransType = 3
	BEGIN
		INSERT INTO @tmpStatus (StatusId)
		SELECT 0 UNION ALL
		SELECT 1
	END

	DECLARE @tmpBettransLC TABLE (
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
		Comm			MONEY,
		PlayerComm		MONEY,
		Ip				NVARCHAR(15),
		TransDesc		NVARCHAR(1000),
		BetCheck		NVARCHAR(50),
		MatchCode		VARCHAR(50)
	)

	IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO @tmpBettransLC
		SELECT
			blc.transid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			blc.transdate,
			blc.winlostdate,
			blc.status,
			blc.statusID,
			blc.odds,
			blc.stake,
			blc.actual_stake,
			(blc.winlost - blc.actual_stake) AS WinLost,
			blc.comm,
			blc.playercomm,
			blc.ip,
			blc.transdesc,
			CASE
				WHEN sbt.productID IN (21, 45) THEN blc.TranId3rd
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.productID IN (21, 45) THEN blc.GameId3rd
				ELSE ''
			END AS MatchCode
		FROM dbo.bettransLC AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
		WHERE blc.custid = @CustId 
			AND blc.RefNo = @RefNo
			AND blc.statusID IN (SELECT StatusId FROM @tmpStatus)
	END
	ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO @tmpBettransLC
		SELECT
			blc.transid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			blc.transdate,
			blc.winlostdate,
			blc.status,
			blc.statusID,
			blc.odds,
			blc.stake,
			blc.actual_stake,
			(blc.winlost - blc.actual_stake) AS WinLost,
			blc.comm,
			blc.playercomm,
			blc.ip,
			blc.transdesc,
			CASE
				WHEN sbt.productID IN (21, 45) THEN blc.TranId3rd
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.productID IN (21, 45) THEN blc.GameId3rd
				ELSE ''
			END AS MatchCode
		FROM dbo.bettransLC14 AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
		WHERE blc.custid = @CustId AND blc.RefNo = @RefNo
	END
	ELSE IF EXISTS ( SELECT 1 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO @tmpBettransLC
		SELECT
			blc.transid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			blc.transdate,
			blc.winlostdate,
			blc.status,
			blc.statusID,
			blc.odds,
			blc.stake,
			blc.actual_stake,
			(blc.winlost - blc.actual_stake) AS WinLost,
			blc.comm,
			blc.playercomm,
			blc.ip,
			blc.transdesc,
			CASE
				WHEN sbt.productID IN (21, 45) THEN blc.TranId3rd
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.productID IN (21, 45) THEN blc.GameId3rd
				ELSE ''
			END AS MatchCode
		FROM DBARC.bodb_Archive.dbo.bettransLC_bk AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
		WHERE blc.custid = @CustId AND blc.RefNo = @RefNo
	END

	-- Get exchange rate
	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM @tmpBettransLC

	-- Get exchange rate
	DECLARE @ExchangeRate TABLE (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	-- Get currency (for security)
	DECLARE @Currency INT

	SELECT @Currency = currency
	FROM dbo.custinfo WITH (NOLOCK)
	WHERE custid = @CustId
		AND currency IN (SELECT DISTINCT Currency FROM @TempAg)

	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO @ExchangeRate
		SELECT
			e.FirstExchangeDateByMonth,
			e.LastExchangeDateByMonth,
			CASE
				WHEN @BaseCurrency = 'MYR' THEN e.MYR
				WHEN @BaseCurrency = 'USD' THEN e.USD
				WHEN @BaseCurrency = 'EUR' THEN e.EUR
				WHEN @BaseCurrency = 'CNY' THEN e.CNY
				WHEN @BaseCurrency = 'IDR' THEN e.IDR
				WHEN @BaseCurrency = 'GBP' THEN e.GBP
				WHEN @BaseCurrency = 'THB' THEN e.THB
				WHEN @BaseCurrency = 'INH' THEN e.INH
				ELSE 1
			END AS Rate
		FROM dbo.Lrf_f_GetSubExchangeDaily(@ExFromDate, @ExToDate) AS e
		WHERE e.ExchangeId = @Currency
			AND EXISTS (SELECT 1 FROM @tmpBettransLC WHERE WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)
	END

	SELECT
		b.TransId,
		b.SportType,
		b.BetType,
		b.TransDate,
		b.WinLostDate,
		b.Status,
		b.StatusId,
		b.Odds,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.Actual_Stake,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		b.Comm * ISNULL(e.Rate, 1) AS Comm,
		b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		b.Ip,
		b.TransDesc,
		b.BetCheck,
		b.MatchCode
	FROM @tmpBettransLC AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY b.TransId ASC
END
GO


GRANT EXECUTE ON [dbo].[Lrf_BetList_LC_Detail] TO [bodbLicenseeNet] AS [dbo]
GO
