/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_CashOut_Detail]
	@AgentList			VARCHAR(MAX),
	@TransId			BIGINT,
	@RefNo				BIGINT,
	@BetType			SMALLINT,
	@OriginalTransId	BIGINT		= 0,
	@BaseCurrency		VARCHAR(10)	= ''
AS

/*
	Created: Kos@20170321
	Task: Get ticket detail of CashOut ticket [#Redmine: 71963]
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]
		- 20180502@Kos: Missing return GBP base currency data [#Redmine: 94431]
		- 20180719@Kos: Support more base currencies [#Redmine: 80941]
		- 20181114@Kos: Change getting ticket status [#Redmine: 104664]
		- 20181121@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
		- 20190426@Kos: Support base currency INH [Redmine: #112603]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @CustId			INT,
		@WinLostDate		SMALLDATETIME,
		@WhTicket			TINYINT,
		@CashOutCustId		INT,
		@CashOutUsername	NVARCHAR(50)

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

	IF @BetType NOT IN (911, 912)
	BEGIN
		IF @RefNo = 100000000000	-- Bet ticket
		BEGIN
			SET @OriginalTransId = @TransId
		END
		ELSE	-- CashOut bet ticket
		BEGIN
			IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @TransId )
			BEGIN
				SELECT @OriginalTransId = refno
				FROM dbo.bettrans WITH (NOLOCK)
				WHERE transid = @RefNo AND bettype = 911
			END
			ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @TransId )
			BEGIN
				SELECT @OriginalTransId = refno
				FROM dbo.bettrans14 WITH (NOLOCK)
				WHERE transid = @RefNo AND bettype = 911
			END
			ELSE IF EXISTS ( SELECT 1 FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @TransId )
			BEGIN
				SELECT @OriginalTransId = refno
				FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK)
				WHERE transid = @RefNo AND bettype = 911
			END
		END
	END

	-- Create temp table
	DECLARE @Data TABLE (
		BetType				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				NVARCHAR(50),
		MatchCode			NVARCHAR(50),
		EventDate			SMALLDATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		OddsType			TINYINT,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(50),
		LiveIndicator		BIT,
		Modds				MONEY,
		CustId				INT,
		Currency			SMALLINT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		LeagueId			INT,
		SportType			SMALLINT,
		Ip					NVARCHAR(15),
		MatchId				INT,
		IsNeutral			BIT,
		WinLost				MONEY,
		PlayerComm			MONEY,
		ShowTime			NVARCHAR(50),
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		OddsSpread			SMALLMONEY,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT
	)

	DECLARE @CashOutData TABLE (
		BetType		INT,
		TransId		BIGINT,
		RefNo		NVARCHAR(50),
		Status		NVARCHAR(50),
		Stake		MONEY,
		TransDate	DATETIME,
		WinLostDate	SMALLDATETIME,
		Currency	SMALLINT,
		CustId		INT,
		Price		MONEY,
		WinLost		MONEY
	)

	-- Get ticket
	IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @OriginalTransId )
	BEGIN
		SELECT
			@CustId = custid,
			@WinLostDate = winlostdate,
			@WhTicket = 1
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE transid = @OriginalTransId

		INSERT INTO @Data
		SELECT
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0) AS BetId,
			b.refno,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			m.homeid,
			m.awayid,
			m.betstatus,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,			
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.modds,
			b.custid,
			b.currency,
			b.livehomescore,
			b.liveawayscore,
			m.leagueid,
			m.sporttype,
			b.ip,
			b.matchid,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm,
			m.showtime,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.transid = @OriginalTransId
			AND b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
	END
	ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @OriginalTransId )
	BEGIN
		SELECT
			@CustId = custid,
			@WinLostDate = winlostdate,
			@WhTicket = 2
		FROM dbo.bettrans14 WITH (NOLOCK)
		WHERE transid = @OriginalTransId

		INSERT INTO @Data
		SELECT
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0) AS BetId,
			b.refno,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			m.homeid,
			m.awayid,
			m.betstatus,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			b.status,
			0 AS SettlementStatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.modds,
			b.custid,
			b.currency,
			b.livehomescore,
			b.liveawayscore,
			m.leagueid,
			m.sporttype,
			b.ip,
			b.matchid,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm,
			m.showtime,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.transid = @OriginalTransId
			AND b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
	END
	ELSE IF EXISTS ( SELECT 1 FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @OriginalTransId )
	BEGIN
		SELECT
			@CustId = custid,
			@WinLostDate = winlostdate,
			@WhTicket = 3
		FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK)
		WHERE transid = @OriginalTransId

		INSERT INTO @Data
		SELECT
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0) AS BetId,
			b.refno,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			m.homeid,
			m.awayid,
			m.betstatus,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			b.status,
			0 AS SettlementStatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.modds,
			b.custid,
			b.currency,
			b.livehomescore,
			b.liveawayscore,
			m.leagueid,
			m.sporttype,
			b.ip,
			b.matchid,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm,
			m.showtime,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.transid = @OriginalTransId
			AND b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
	END

	-- Get CashOut dummy acc custid
	SELECT @CashOutUsername = a.username + 'CashOut'
	FROM dbo.custInfo AS a WITH (NOLOCK)
		INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.recommend = a.custid 
	WHERE c.custid = @CustId

	SELECT @CashOutCustId = custid
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE username = @CashOutUsername

	-- Get CashOut/Bought ticket
	DECLARE @GetCashOutTicket TINYINT = 0

	IF @BetType = 911 OR @RefNo = 100000000000
		SET @GetCashOutTicket = 1

	IF @WhTicket = 1
	BEGIN
		INSERT INTO @CashOutData
		SELECT
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.bettype
				ELSE bb.bettype
			END AS BetType,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.transid
				ELSE bb.transid
			END AS TransId,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.refno
				ELSE bb.refno
			END AS RefNo,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.status
				ELSE bb.status
			END AS Status,
			b.stake AS Stake,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.transdate
				ELSE bb.transdate
			END AS TransDate,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.winlostdate
				ELSE bb.winlostdate
			END AS WinLostDate,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.currency
				ELSE bb.currency
			END AS Currency,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.custid
				ELSE bb.custid
			END AS CustId,
			bb.actual_stake AS Price,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.winlost - b.actual_stake
				ELSE bb.winlost - bb.actual_stake
			END AS WinLost
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS bb WITH (NOLOCK) ON bb.refno = b.transid
		WHERE b.custid = @CustId
			AND b.winlostdate = @WinLostDate
			AND b.refno = @OriginalTransId
			AND b.bettype = 911
			AND bb.custid = @CashOutCustId
			AND bb.winlostdate = @WinLostDate
			AND bb.bettype = 912
	END
	ELSE IF @WhTicket = 2
	BEGIN
		INSERT INTO @CashOutData
		SELECT
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.bettype
				ELSE bb.bettype
			END AS BetType,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.transid
				ELSE bb.transid
			END AS TransId,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.refno
				ELSE bb.refno
			END AS RefNo,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.status
				ELSE bb.status
			END AS Status,
			b.stake AS Stake,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.transdate
				ELSE bb.transdate
			END AS TransDate,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.winlostdate
				ELSE bb.winlostdate
			END AS WinLostDate,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.currency
				ELSE bb.currency
			END AS Currency,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.custid
				ELSE bb.custid
			END AS CustId,
			bb.actual_stake AS Price,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.winlost - b.actual_stake
				ELSE bb.winlost - bb.actual_stake
			END AS WinLost
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.bettrans14 AS bb WITH (NOLOCK) ON bb.refno = b.transid
		WHERE b.custid = @CustId
			AND b.winlostdate = @WinLostDate
			AND b.refno = @OriginalTransId
			AND b.bettype = 911
			AND bb.custid = @CashOutCustId
			AND bb.winlostdate = @WinLostDate
			AND bb.bettype = 912
	END
	ELSE IF @WhTicket = 3
	BEGIN
		INSERT INTO @CashOutData
		SELECT
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.bettype
				ELSE bb.bettype
			END AS BetType,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.transid
				ELSE bb.transid
			END AS TransId,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.refno
				ELSE bb.refno
			END AS RefNo,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.status
				ELSE bb.status
			END AS Status,
			b.stake AS Stake,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.transdate
				ELSE bb.transdate
			END AS TransDate,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.winlostdate
				ELSE bb.winlostdate
			END AS WinLostDate,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.currency
				ELSE bb.currency
			END AS Currency,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.custid
				ELSE bb.custid
			END AS CustId,
			bb.actual_stake AS Price,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.winlost - b.actual_stake
				ELSE bb.winlost - bb.actual_stake
			END AS WinLost
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN bodb_Archive.dbo.bettrans_bk AS bb WITH (NOLOCK) ON bb.refno = b.transid
		WHERE b.custid = @CustId
			AND b.winlostdate = @WinLostDate
			AND b.refno = @OriginalTransId
			AND b.bettype = 911
			AND bb.custid = @CashOutCustId
			AND bb.winlostdate = @WinLostDate
			AND bb.bettype = 912
	END

	DECLARE @Today SMALLDATETIME

	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	IF @WinLostDate > @Today
		SET @WinLostDate = @Today
		
	-- Get exchange rate
	DECLARE @ExchangeRate AS TABLE (
		ExchangeDate	SMALLDATETIME,
		ExchangeId		INT,
		Rate			FLOAT
	)
	
	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO @ExchangeRate
		SELECT
			e.exchangedate,
			e.ExchangeId,
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
		FROM dbo.Lrf_f_GetExchangeDaily(@WinLostDate, @WinLostDate) AS e
		WHERE EXISTS (SELECT 1 FROM @Data WHERE Currency = e.ExchangeId)
	END

	SELECT
		b.BetType,
		b.TransId,
		b.BetId,
		b.RefNo,
		b.MatchCode,
		b.EventDate,
		b.HomeId,
		b.AwayId,
		b.BetStatus,
		b.Hdp1,
		b.Hdp2,
		b.Odds,
		b.OddsType,
		b.Status,
		b.SettlementStatus,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.Actual_Stake,
		b.TransDate,
		b.BetTeam,
		b.LiveIndicator,
		b.Modds,
		b.CustId,
		b.Currency,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.LeagueId,
		b.SportType,
		b.Ip,
		b.MatchId,
		b.IsNeutral,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		b.ShowTime,
		b.WinLostDate,
		b.BetCheck,
		b.TransDesc,
		b.OddsSpread,
		b.BetdaqId,
		b.ExtraInfo,
		b.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		b.OriginalBetType
	FROM @Data AS b
		LEFT JOIN @ExchangeRate AS e
			ON e.ExchangeDate = (CASE WHEN b.WinLostDate <= @Today THEN b.WinLostDate ELSE @Today END) AND e.exchangeid = b.Currency

	SELECT
		b.BetType,
		b.TransId,
		b.RefNo,
		b.Status,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.TransDate,
		b.WinLostDate,
		b.Currency,
		b.CustId,
		b.Price * ISNULL(e.Rate, 1) AS Price,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost
	FROM @CashOutData AS b
		LEFT JOIN @ExchangeRate AS e
			ON e.ExchangeDate = (CASE WHEN b.WinLostDate <= @Today THEN b.WinLostDate ELSE @Today END) AND e.exchangeid = b.Currency
END
GO




GRANT EXECUTE ON [dbo].[Lrf_BetList_CashOut_Detail] TO [bodbLicenseeNet] AS [dbo]
GO
