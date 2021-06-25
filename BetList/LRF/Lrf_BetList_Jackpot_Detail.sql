/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Jackpot_Detail]
	@AgentList		VARCHAR(MAX),
	@TransId		BIGINT,
	@CustId			INT,
	@BaseCurrency	VARCHAR(10)
AS

/*
	Created: Kos@20200714
	Task: Get Jackpot Won ticket detail
	DB: DBACC.bodb02

	Revisions:
		- 20200714@Kos: Support PP Jackpot [Redmine: #137290]
		- 20210118@Kos: Support Saba.club Jackpot Contribution and Jackpot Prize tickets [Redmine: #148100]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210720@Kos: Support Vgaming [Redmine: 158106]
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

	-- Get Sport Bettype Matrix
	-- Support PP, Saba.club, Vgaming
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (32, 42, 66)

	-- Create temp table
	DECLARE @Data TABLE (
		TransId			BIGINT,
		RefNo			BIGINT,
		Currency		SMALLINT,
		Recommend		INT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		SportType		INT,
		BetType			INT,
		Status			NVARCHAR(10),
		StatusId		TINYINT,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Ip				NVARCHAR(15),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		BetdaqId		BIGINT
	)

	-- Get ticket
	IF EXISTS ( SELECT TOP(1) 1
				FROM dbo.bettransRnG AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.BetType
				WHERE b.transid = @TransId AND b.custid = @CustId )
	BEGIN
		INSERT INTO @Data
		SELECT
			b.transid,
			b.RefNo,
			b.currency,
			b.recommend,
			b.transdate,
			b.winlostdate,
			b.productID AS SportType,
			b.gameID AS BetType,
			b.status,
			b.statusID,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm AS Comm,
			b.playercomm AS PlayerComm,
			b.ip,
			b.TranId3rd AS BetCheck,
			b.transdesc,
			ISNULL(b.RefNo2, -1) AS BetdaqId
		FROM dbo.bettransRnG AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.Bettype
		WHERE b.custid = @CustId AND b.transid = @TransId
	END
	ELSE IF EXISTS ( SELECT TOP(1) 1
					FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.BetType
					WHERE b.transid = @TransId AND b.custid = @CustId )
	BEGIN
		INSERT INTO @Data
		SELECT
			b.transid,
			b.RefNo,
			b.currency,
			b.recommend,
			b.transdate,
			b.winlostdate,
			b.productID AS SportType,
			b.gameID AS BetType,
			b.status,
			b.statusID,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm AS Comm,
			b.playercomm AS PlayerComm,
			b.ip,
			b.TranId3rd AS BetCheck,
			b.transdesc,
			ISNULL(b.RefNo2, -1) AS BetdaqId
		FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.Bettype
		WHERE b.custid = @CustId AND b.transid = @TransId
	END
	ELSE IF EXISTS ( SELECT TOP(1) 1
					FROM bodb_Archive.dbo.bettransRnG_bk AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.BetType
					WHERE b.transid = @TransId AND b.custid = @CustId )
	BEGIN
		INSERT INTO @Data
		SELECT
			b.transid,
			b.RefNo,
			b.currency,
			b.recommend,
			b.transdate,
			b.winlostdate,
			b.productID AS SportType,
			b.gameID AS BetType,
			b.status,
			b.statusID,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm AS Comm,
			b.playercomm AS PlayerComm,
			b.ip,
			b.TranId3rd AS BetCheck,
			b.transdesc,
			ISNULL(b.RefNo2, -1) AS BetdaqId
		FROM bodb_Archive.dbo.bettransRnG_bk AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.Bettype
		WHERE b.custid = @CustId AND b.transid = @TransId
	END

	DELETE b
	FROM @Data AS b
	WHERE NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)

	-- Get exchange rate
	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM @Data

	-- Get exchange rate
	DECLARE @ExchangeRate TABLE (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

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
				WHEN @BaseCurrency = 'BDT' THEN e.BDT
				WHEN @BaseCurrency = 'INR' THEN e.INR
				ELSE 1
			END AS Rate
		FROM dbo.Lrf_f_GetSubExchangeDaily(@ExFromDate, @ExToDate) AS e
		WHERE EXISTS (SELECT 1 FROM @Data 
					WHERE Currency = e.ExchangeId
						AND WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)
	END

	SELECT
		b.TransId,
		b.RefNo,
		b.Currency,
		b.TransDate,
		b.WinLostDate,
		b.SportType,
		b.BetType,
		b.Status,
		b.StatusId,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.Actual_Stake,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		b.Comm * ISNULL(e.Rate, 1) AS Comm,
		b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		b.ip,
		b.BetCheck,
		b.TransDesc,
		b.BetdaqId
	FROM @Data AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
END
GO
