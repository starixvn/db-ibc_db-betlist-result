USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Acc_BetList_BetTrade_Detail]    Script Date: 8/4/2016 1:33:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_LicenseeBonus_Detail]
	@AgentList	VARCHAR(MAX),
	@TransId	BIGINT,
	@RefCode	BIGINT
AS

/*
	Created: Kos@20170515
	Task: Get ticket detail of Licensee Bonus System ticket [#Redmine: 74978]
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]

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
			ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH

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
		ComStatus		NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(50),
		LiveIndicator	BIT,
		MOdds			MONEY,
		CustId			INT,
		Currency		SMALLINT,
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		LeagueId		INT,
		SportType		SMALLINT,
		Ip				NVARCHAR(15),
		MatchId			INT,
		IsNeutral		BIT,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Discount		SMALLMONEY,
		ShowTime		NVARCHAR(50),
		WinLostDate		SMALLDATETIME,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		OddsSpread		SMALLMONEY,
		WalletType		TINYINT,
		RefCode			BIGINT
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
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
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
			0 AS RefCode
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
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
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
			0 AS RefCode
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
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
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
			0 AS RefCode
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

	SELECT *
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@WinLostDate, @WinLostDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM @Data)

	SELECT
		b.*,
		b.Stake * e.USD AS StakeUSD,
		b.Stake * e.EUR AS StakeEUR,
		b.Stake * e.MYR AS StakeMYR,
		b.Actual_Stake * e.USD AS Actual_StakeUSD,
		b.Actual_Stake * e.EUR AS Actual_StakeEUR,
		b.Actual_Stake * e.MYR AS Actual_StakeMYR,
		b.WinLost * e.USD AS WinLostUSD,
		b.WinLost * e.EUR AS WinLostEUR,
		b.WinLost * e.MYR AS WinLostMYR,
		b.LicenseeWL * e.USD AS LicenseeWLUSD,
		b.LicenseeWL * e.EUR AS LicenseeWLEUR,
		b.LicenseeWL * e.MYR AS LicenseeWLMYR,
		b.Comm * e.USD AS CommUSD,
		b.Comm * e.EUR AS CommEUR,
		b.Comm * e.MYR AS CommMYR,
		b.PlayerComm * e.USD AS PlayerCommUSD,
		b.PlayerComm * e.EUR AS PlayerCommEUR,
		b.PlayerComm * e.MYR AS PlayerCommMYR
	FROM @Data AS b
		INNER JOIN #TempExchange AS e
			ON e.ExchangeDate = (CASE WHEN b.WinLostDate <= @Today THEN b.WinLostDate ELSE @Today END) AND e.exchangeid = b.Currency
	ORDER BY b.TransId

	DROP TABLE #TempExchange
END





GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LicenseeBonus_Detail] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LicenseeBonus_Detail] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LicenseeBonus_Detail] TO [vnteam] AS [dbo]
GO
