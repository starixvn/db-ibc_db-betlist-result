/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_LicenseeBonus_Detail]
	@AgentList		VARCHAR(MAX),
	@TransId		BIGINT,
	@RefCode		BIGINT,
	@BaseCurrency	VARCHAR(10)	= ''
AS

/*
	Created: Kos@20170515
	Task: Get ticket detail of Licensee Bonus System ticket [#Redmine: 74978]
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]
		- 20180502@Kos: Missing return GBP base currency data [#Redmine: 94431]
		- 20180719@Kos: Support more base currencies [#Redmine: 80941]
		- 20181012@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
		- 20181218@Kos: Support E-Sports phase 2b [#Redmine: 106553]
		- 20190426@Kos: Support base currency INH [Redmine: #112603]

	Parameters:
		- @TransId: TransId of summary ticket of multiple of Bonus/Cash sub tickets
		- @RefCode: RefCode of summary ticket
			- @TransId = @RefCode: summary ticket is from single Bonus sub ticket only
			- @TransId <> @RefCode: summary ticket is from multiple Bonus/Cash sub ticket
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
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(50),
		LiveIndicator		BIT,
		MOdds				MONEY,
		CustId				INT,
		Currency			SMALLINT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		LeagueId			INT,
		SportType			SMALLINT,
		Ip					NVARCHAR(15),
		MatchId				INT,
		IsNeutral			BIT,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		Discount			SMALLMONEY,
		ShowTime			NVARCHAR(50),
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		OddsSpread			SMALLMONEY,
		WalletType			TINYINT,
		RefCode				BIGINT,
		ExtraInfo			VARCHAR(1000)
	)

	DECLARE @CustId		INT,
		@WinLostDate	SMALLDATETIME,
		@WhTicket		TINYINT

	SELECT @CustId = b.custid,
		@WinLostDate = b.winlostdate,
		@WhTicket = 1
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.transid = @TransId
		AND (b.RefCode = @RefCode OR @TransId = @RefCode)

	IF @WinLostDate IS NULL
	BEGIN
		SELECT @CustId = b.custid,
			@WinLostDate = b.winlostdate,
			@WhTicket = 2
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE b.transid = @TransId
			AND (b.RefCode = @RefCode OR @TransId = @RefCode)

		IF @WinLostDate IS NULL
		BEGIN
			SELECT @CustId = b.custid,
				@WinLostDate = b.winlostdate,
				@WhTicket = 3
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			WHERE b.transid = @TransId
				AND (b.RefCode = @RefCode OR @TransId = @RefCode)
		END
	END

	-- Get ticket
	IF @WhTicket = 1	-- Bettrans range
	BEGIN
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
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
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
			m.finalhomescore,
			m.finalawayscore,
			m.leagueid,
			m.sporttype,
			b.ip,
			b.matchid,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			m.showtime,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.WalletType, 0) AS WalletType,
			0 AS RefCode,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.custid = @CustId
			AND b.winlostdate = @WinLostDate
			AND b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
			AND ((@TransId = @RefCode AND b.transid = @TransId)
				OR (@TransId <> @RefCode AND b.RefCode = @RefCode))
	END
	ELSE IF @WhTicket = 2	-- Bettrans14 range
	BEGIN
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
			m.betstatus,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			0 AS SettlementStatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
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
			m.finalhomescore,
			m.finalawayscore,
			m.leagueid,
			m.sporttype,
			b.ip,
			b.matchid,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			m.showtime,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.WalletType, 0) AS WalletType,
			0 AS RefCode,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.custid = @CustId
			AND b.winlostdate = @WinLostDate
			AND b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
			AND ((@TransId = @RefCode AND b.transid = @TransId)
				OR (@TransId <> @RefCode AND b.RefCode = @RefCode))
	END
	ELSE IF @WhTicket = 3	-- Bettrans_bk range
	BEGIN
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
			m.betstatus,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			0 AS SettlementStatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
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
			m.finalhomescore,
			m.finalawayscore,
			m.leagueid,
			m.sporttype,
			b.ip,
			b.matchid,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			m.showtime,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.WalletType, 0) AS WalletType,
			0 AS RefCode,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.custid = @CustId
			AND b.winlostdate = @WinLostDate
			AND b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
			AND ((@TransId = @RefCode AND b.transid = @TransId)
				OR (@TransId <> @RefCode AND b.RefCode = @RefCode))
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
		b.ComStatus,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
		b.TransDate,
		b.BetTeam,
		b.LiveIndicator,
		b.MOdds,
		b.CustId,
		b.Currency,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.FinalHomeScore,
		b.FinalAwayScore,
		b.LeagueId,
		b.SportType,
		b.Ip,
		b.MatchId,
		b.IsNeutral,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		b.Comm * ISNULL(e.Rate, 1) AS Comm,
		b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		b.Discount,
		b.ShowTime,
		b.WinLostDate,
		b.BetCheck,
		b.TransDesc,
		b.OddsSpread,
		b.WalletType,
		b.RefCode,
		b.ExtraInfo
	FROM @Data AS b
		LEFT JOIN @ExchangeRate AS e
			ON e.ExchangeDate = (CASE WHEN b.WinLostDate <= @Today THEN b.WinLostDate ELSE @Today END) AND e.exchangeid = b.Currency
	ORDER BY b.TransId
END
GO




GRANT EXECUTE ON [dbo].[Lrf_BetList_LicenseeBonus_Detail] TO [bodbLicenseeNet] AS [dbo]
GO
