USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_CashOut_Detail]    Script Date: 3/29/2017 4:38:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_CashOut_Detail]
	@AgentList			VARCHAR(MAX),
	@TransId			BIGINT,
	@RefNo				BIGINT,
	@BetType			SMALLINT,
	@OriginalTransId	BIGINT		= 0
AS

/*
	Created: Kos@20170321
	Task: Get ticket detail of CashOut ticket [#Redmine: 71963]
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]
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
			ErrMsg = N'Paramter invalid.'

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
		BetType			INT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			NVARCHAR(50),
		MatchCode		NVARCHAR(50),
		EventDate		SMALLDATETIME,
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		OddsType		TINYINT,
		Status			NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(50),
		LiveIndicator	BIT,
		Modds			MONEY,
		CustId			INT,
		Currency		SMALLINT,
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		LeagueId		INT,
		SportType		SMALLINT,
		Ip				NVARCHAR(15),
		MatchId			INT,
		IsNeutral		BIT,
		WinLost			MONEY,
		PlayerComm		MONEY,
		ShowTime		NVARCHAR(50),
		WinLostDate		SMALLDATETIME,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		OddsSpread		SMALLMONEY,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT
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
			m.eventdate,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			b.status,
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
			m.eventdate,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			b.status,
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
			m.eventdate,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			b.status,
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

	SELECT *
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@WinLostDate, @WinLostDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM @Data)

	SELECT
		b.*,
		b.Stake * e.USD AS StakeUSD,
		b.Stake * e.EUR AS StakeEUR,
		b.Stake * e.MYR AS StakeMYR,
		b.WinLost * e.USD AS WinLostUSD,
		b.WinLost * e.EUR AS WinLostEUR,
		b.WinLost * e.MYR AS WinLostMYR,
		b.PlayerComm * e.USD AS PlayerCommUSD,
		b.PlayerComm * e.EUR AS PlayerCommEUR,
		b.PlayerComm * e.MYR AS PlayerCommMYR,
		b.OriginalStake * e.USD AS OriginalStakeUSD,
		b.OriginalStake * e.EUR AS OriginalStakeEUR,
		b.OriginalStake * e.MYR AS OriginalStakeMYR
	FROM @Data AS b
		INNER JOIN #TempExchange AS e
			ON e.ExchangeDate = (CASE WHEN b.WinLostDate <= @Today THEN b.WinLostDate ELSE @Today END) AND e.exchangeid = b.Currency

	SELECT
		b.*,
		b.Stake * e.USD AS StakeUSD,
		b.Stake * e.EUR AS StakeEUR,
		b.Stake * e.MYR AS StakeMYR,
		b.Price * e.USD AS PriceUSD,
		b.Price * e.EUR AS PriceEUR,
		b.Price * e.MYR AS PriceMYR,
		b.WinLost * e.USD AS WinLostUSD,
		b.WinLost * e.EUR AS WinLostEUR,
		b.WinLost * e.MYR AS WinLostMYR
	FROM @CashOutData AS b
		INNER JOIN #TempExchange AS e
			ON e.ExchangeDate = (CASE WHEN b.WinLostDate <= @Today THEN b.WinLostDate ELSE @Today END) AND e.exchangeid = b.Currency

	DROP TABLE #TempExchange
END




GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_CashOut_Detail] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_CashOut_Detail] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_CashOut_Detail] TO [vnteam] AS [dbo]
GO
