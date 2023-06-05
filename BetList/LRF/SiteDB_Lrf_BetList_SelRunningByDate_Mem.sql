/*<info serverAlias="DBSID-bodb02" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Lrf_BetList_SelRunningByDate_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT			= NULL,
	@FromDate		DATETIME	= '',
	@ToDate			DATETIME	= '',
	@Username		VARCHAR(30)	= NULL, -- for API
	@ExcludeFreeBet	BIT			= 0,	-- Exclude free tickets
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT			= 1000,
	@PageIndex		INT			= 1,
	-- check for showing product
	@ShowSB		BIT			= 0,	-- Sportsbook
	@ShowNG		BIT			= 0,	-- Number Game
	@ShowBA		BIT			= 0,
	@ShowVS		BIT			= 0,	-- Virtual Sports
	@ShowCS		BIT			= 0,	-- RNG Casino
	@ShowKN		BIT			= 0,	-- Keno
	@ShowAGC	BIT			= 0,	-- AG Casino
	@ShowAB		BIT			= 0,	-- AllBet
	@ShowVB		BIT			= 0,	-- Voidbridge
	@ShowVS2	BIT			= 0,	-- Betradar Virtual Sports
	@ShowLT		BIT			= 0,	-- Lottery
	@ShowPP		BIT			= 0,	-- Pragmatic Casino
	@ShowCC		BIT			= 0,	-- Card Club
	@ShowSG		BIT			= 0,	-- Spadegaming
	@ShowVRG	BIT			= 0,	-- Virtual Games
	@ShowSAG	BIT			= 0,	-- SA Gaming
	@ShowTG		BIT			= 0,	-- Table Games
	@ShowSBC	BIT			= 0,	-- Saba.club
	@ShowI4D	BIT			= 0,	-- Indo 4D
	@ShowSXG	BIT			= 0,	-- Sexy Gaming
	@ShowPGS	BIT			= 0,	-- PG Soft
	@ShowJK		BIT			= 0,	-- Joker
	@ShowSLT	BIT			= 0,	-- Sports Lottery
	@ShowHB		BIT			= 0,	-- Habanero
	@ShowWM		BIT			= 0,	-- WM Live Casino
	@ShowBGG	BIT			= 0,	-- Big Gaming
	@ShowVGA	BIT			= 0,	-- Vgaming
	@ShowCG		BIT			= 0,	-- CG
	@ShowAP		BIT			= 0,	-- AdvantPlay
	@ShowAPM	BIT			= 0,	-- AdvantPlay Mini
	@ShowBTC	BIT			= 0,	-- Bitcoin
	@ShowVS3	BIT			= 0,	-- Virtual Sports 3
	@ShowFGGL	BIT			= 0,	-- FGG
	@ShowMXG	BIT			= 0,	-- MaxGame
	@ShowJIG	BIT			= 0,	-- Jili
	@ShowYB		BIT			= 0,	-- YeeBet
	-- output info
	@TotalRows	INT			= 0 OUTPUT,
	@ErrorCode	INT			= 0 OUTPUT,
	@ErrorMsg	NVARCHAR(100)='' OUTPUT
AS

/*
	Created: 20220727@Kos
	Task: LAP - Outstanding Report Bet list - SiteDB
	DB: DBSID.bodb02

	Revisions:
		- 20220727@Kos: Created [Redmine: #175297]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20230119@Kos: Support Jili [Redmine: 182914]
		- 20230328@Kos: Remove inactive products CB, FW, GDG [Redmine: 181424]
		- 20230602@Kos: Support YeeBet [Redmine: 187947]
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

	DECLARE @Today		SMALLDATETIME
		, @Yesterday	SMALLDATETIME
	
	SELECT @Today = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
		, @Yesterday = DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
		, @TotalRows = 0
		, @ErrorCode = 0
		, @ErrorMsg = ''

	IF @CustID IS NULL
	BEGIN
		SELECT TOP(1)
			@CustId = custid
			, @Username = CASE WHEN @Username IS NULL THEN username ELSE @Username END
		FROM CustDB.dbo.Customer WITH (NOLOCK)
		WHERE username = @Username
			AND currency IN (SELECT DISTINCT Currency FROM @TempAg)
	END
	ELSE
	BEGIN
		SELECT TOP(1)
			@CustId = @custid
			, @Username = CASE WHEN @Username IS NULL THEN username ELSE @Username END
		FROM CustDB.dbo.Customer WITH (NOLOCK)
		WHERE custid = @CustId
			AND currency IN (SELECT DISTINCT Currency FROM @TempAg)
	END

	IF @CustId IS NULL OR @Username IS NULL
	BEGIN
		SELECT @ErrorCode = 100,
			@ErrorMsg = 'The customer was not found.'
		RETURN;
	END

	-- Get SportBetTypeMatrix
	-- Don't support BetTrade, RNG Casino old bet type (71, 72)
	DECLARE @SportBettype TABLE ( ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 3, 5, 6, 8, 11, 21, 22, 27, 28, 32, 34, 36, 38, 39, 40, 42, 43, 45, 49, 51, 55, 56, 57, 60, 61, 62, 63, 66, 67, 68, 69, 70, 75, 76)
		AND BetType NOT IN (71, 72, 801, 802, 803, 804, 805, 806, 901, 902, 903, 904)

	DELETE FROM @SportBettype
	WHERE ProductID		= CASE WHEN @ShowSB = 0 AND @ShowBA = 0 THEN 1 END
		OR ProductID	= CASE WHEN @ShowNG = 0		THEN 3 END
		OR ProductID	= CASE WHEN @ShowVS = 0		THEN 5 END
		OR ProductID	= CASE WHEN @ShowCS = 0		THEN 6 END
		OR ProductID	= CASE WHEN @ShowKN = 0		THEN 8 END
		OR ProductID	= CASE WHEN @ShowAGC = 0	THEN 11 END
		OR ProductID	= CASE WHEN @ShowAB = 0		THEN 21 END
		OR ProductID	= CASE WHEN @ShowVB = 0		THEN 22 END
		OR ProductID	= CASE WHEN @ShowVS2 = 0	THEN 27 END
		OR ProductID	= CASE WHEN @ShowLT = 0		THEN 28 END
		OR ProductID	= CASE WHEN @ShowPP = 0		THEN 32 END
		OR ProductID	= CASE WHEN @ShowCC = 0		THEN 34 END
		OR ProductID	= CASE WHEN @ShowSG = 0		THEN 36 END
		OR ProductID	= CASE WHEN @ShowVRG = 0	THEN 38 END
		OR ProductID	= CASE WHEN @ShowSAG = 0	THEN 39 END
		OR ProductID	= CASE WHEN @ShowTG = 0		THEN 40 END
		OR ProductID	= CASE WHEN @ShowSBC = 0	THEN 42 END
		OR ProductID	= CASE WHEN @ShowI4D = 0	THEN 43 END
		OR ProductID	= CASE WHEN @ShowSXG = 0	THEN 45 END
		OR ProductID	= CASE WHEN @ShowVS3 = 0	THEN 49 END
		OR ProductID	= CASE WHEN @ShowWM = 0		THEN 51 END
		OR ProductID	= CASE WHEN @ShowPGS = 0	THEN 55 END
		OR ProductID	= CASE WHEN @ShowJK = 0		THEN 56 END
		OR ProductID	= CASE WHEN @ShowBGG = 0	THEN 57 END
		OR ProductID	= CASE WHEN @ShowMXG = 0	THEN 60 END
		OR ProductID	= CASE WHEN @ShowHB = 0		THEN 61 END
		OR ProductID	= CASE WHEN @ShowCG = 0		THEN 62 END
		OR ProductID	= CASE WHEN @ShowSLT = 0	THEN 63 END
		OR ProductID	= CASE WHEN @ShowVGA = 0	THEN 66 END
		OR ProductID	= CASE WHEN @ShowAP = 0		THEN 67 END
		OR ProductID	= CASE WHEN @ShowAPM = 0	THEN 68 END
		OR ProductID	= CASE WHEN @ShowBTC = 0	THEN 69 END
		OR ProductID	= CASE WHEN @ShowFGGL = 0	THEN 70 END
		OR ProductID	= CASE WHEN @ShowJIG = 0	THEN 75 END
		OR ProductID	= CASE WHEN @ShowYB = 0		THEN 76 END

	CREATE TABLE #BetListSelRunningByDateMem (
		SportType			INT,
		Username			NVARCHAR(50),
		BetType				SMALLINT,
		LeagueId			INT,
		RefNo				BIGINT,
		TransId				BIGINT,
		BetId				BIGINT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		Modds				MONEY,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(50),
		Discount			DECIMAL(9,8),
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		IsNeutral			BIT,
		OddsType			INT,
		ShowTime			NVARCHAR(50),
		MatchId				INT,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		OddsSpread			MONEY
	)

	CREATE TABLE #TempBATicket (
		BetType			INT,
		RefNo			BIGINT,
		TransId			BIGINT PRIMARY KEY,
		BetId			BIGINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Modds			MONEY,
		Status			NVARCHAR(10),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			NVARCHAR(20),
		Discount		DECIMAL(9,8),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(45),
		OddsType		TINYINT,
		MatchId			INT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		OddsSpread		MONEY
	)

	-- Receive BA Ticket - SB ticket only
	INSERT INTO #TempBATicket
	SELECT
		b.bettype,
		b.refno,
		b.transid,
		ISNULL(b.betid, 0),
		b.hdp1,
		b.hdp2,
		b.odds,
		b.modds,
		CASE
			WHEN b.bettype NOT IN (9, 29, 10) AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1
				AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			ELSE b.status
		END AS status,
		b.stake,
		b.actual_stake,
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.discount,
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.ip,
		b.oddstype,
		b.matchid,
		b.betcheck,
		ISNULL(b.transdesc, '') AS TransDesc,
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
		END AS OriginalBetType,
		ISNULL(b.oddsspread, 0) AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.LicenseeBATransaction_active AS BA WITH (NOLOCK) ON b.transid = BA.transid
		INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
	WHERE b.transdate >= @FromDate AND b.transdate <= @ToDate
		AND b.custid = @CustID
		AND sbt.ProductId = 1
		AND b.statusID IN (0, 1)

	IF @ShowBA = 1
	BEGIN
		-- Sportsbook
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			m.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,
			b.RefNo,
			b.TransId,
			b.BetId,
			m.matchcode,
			'' AS Race,
			m.GlobalShowTime AS EventDate,
			m.homeid,
			m.awayid,
			b.Hdp1,
			b.Hdp2,
			b.Odds,
			b.Modds,
			b.Status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			b.Stake,
			b.Actual_Stake,
			b.TransDate,
			b.BetTeam,
			b.Discount,
			b.LiveIndicator,
			b.LiveHomeScore,
			b.LiveAwayScore,
			b.Ip,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			'' AS ShowTime,
			m.matchid,
			b.BetCheck,
			b.TransDesc,
			b.BetdaqId,
			b.ExtraInfo,
			b.OriginalStake,
			b.OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			b.OddsSpread
		FROM #TempBATicket AS b
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE sbt.ProductID = 1 AND sbt.EventType = 1

		-- Outright
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			l.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueid,
			b.refno,
			b.transid,
			b.BetId,
			m.matchcode,
			m.groupmatch AS Race,
			b.WinLostDate AS EventDate,
			m.teamid AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			b.Odds,
			b.Modds,
			b.Status,
			0 AS SettlementStatus,
			b.Stake,
			b.Actual_Stake,
			b.TransDate,
			'' AS Betteam,
			b.Discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.Ip,
			CONVERT(BIT,0) AS IsNeutral,
			b.OddsType,
			'' AS ShowTime,
			0 AS matchid,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			b.ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM #TempBATicket AS b
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE sbt.ProductID = 1 AND sbt.EventType = 2

		-- Mix Parlay & System Parlay
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			0 AS sporttype,
			@Username AS UserName,
			b.BetType,
			0 AS leagueID,
			b.RefNo,
			CASE
				WHEN (ISNULL(b.BetId, 0) = 0 OR b.BetType = 9) THEN b.transid 
				ELSE b.BetId 
			END AS transid,
			b.BetId,
			'' AS matchcode,
			'' AS Race,
			b.WinLostDate AS EventDate,
			0 AS homeID,
			0 AS awayID,
			b.hdp1,
			b.hdp2,
			b.Odds,
			b.Modds,
			CASE
				WHEN b.status = 'running' THEN
					CASE
						WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
									WHERE bm.custid = @CustId
										AND bm.refno = b.refno
										AND (bm.status = 'waiting'
											OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
							THEN 'Waiting'
						ELSE b.status
					END
				ELSE b.status
			END AS Status,
			0 AS SettlementStatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			'' As ShowTime,
			0 AS matchid,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			b.ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM 
			#TempBATicket AS b
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE sbt.ProductID = 1 AND sbt.EventType = 0
	END

	-- Sportsbook
	IF @ShowSB = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			m.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueid,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			m.matchcode,
			'' AS Race,
			m.GlobalShowTime AS EventDate,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.discount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.oddstype,
			'' AS ShowTime,
			m.matchid,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
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
			END AS OriginalBetType,
			ISNULL(b.WalletType, 0) AS WalletType,
			ISNULL(b.RefCode, 0) AS RefCode,
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate >= @FromDate AND b.transdate <= @ToDate
			AND b.custid = @CustID
			AND sbt.ProductID = 1
			AND sbt.EventType = 1
			AND b.matchid > 0
			AND b.statusID IN (0, 1)
			AND b.transid NOT IN (SELECT transid FROM #TempBATicket)

		-- Outright
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			l.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			m.matchcode,
			m.GroupMatch AS Race,
			b.WinLostDate AS EventDate,
			m.teamID AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			b.odds,
			b.modds,
			b.status,
			0 AS SettlementStatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			'' AS Betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			CONVERT(BIT,0) AS IsNeutral,
			b.oddstype,
			'' AS ShowTime,
			0 AS matchid,
			'' AS BetCheck,
			'' AS TransDesc,
			-1 AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate >= @FromDate AND b.transdate <= @ToDate
			AND b.custid = @CustID
			AND sbt.ProductID = 1
			AND sbt.EventType = 2
			AND b.statusID IN (0,1)
			AND b.transid NOT IN (SELECT transid FROM #TempBATicket)
	END

	-- Mix Parlay, System Parlay (Sportsbook), Mix Parlay (Betradar Virtual Sports)
	IF @ShowSB = 1 OR @ShowVS2 = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			0 AS sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,
			CASE
				WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS transid,
			ISNULL(b.betid, 0),
			'' AS matchcode,
			'' AS Race,
			b.WinLostDate AS EventDate,
			0 AS homeID,
			0 AS awayID,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' THEN
					CASE
						WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
									WHERE bm.custid = @CustId
										AND bm.refno = b.refno
										AND (bm.status = 'waiting'
											OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
							THEN 'Waiting'
						ELSE b.status
					END
				ELSE b.status
			END AS Status,
			0 AS SettlementStatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			'' AS ShowTime,
			0 AS matchid,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS TransDesc,
			-1 AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate BETWEEN @FromDate AND @ToDate
			AND b.custid = @CustID
			AND (sbt.ProductID = 27
				OR (sbt.ProductID = 1 AND @ShowSB = 1))		-- check in case of @ShowBA = 1
			AND sbt.EventType = 0
			AND b.statusID IN (0, 1)
			AND b.transid NOT IN (SELECT transid FROM #TempBATicket)
	END

	-- release mem for tempdb
	DROP TABLE #TempBATicket;

	-- Number Game, Virtual Sport, Betradar Virtual Sport
	IF @ShowNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			m.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			m.matchcode,
			'' AS Race,
			b.WinLostDate AS EventDate,
			m.homeID,
			m.awayID,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
				ELSE b.status
			END AS status,
			0 AS SettlementStatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.discount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			CONVERT(BIT,0) AS IsNeutral,
			b.oddstype,
			CASE
				WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE ''
			END AS ShowTime,
			m.matchid,
			'' AS BetCheck,
			CASE
				WHEN sbt.ProductID = 27 THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			-1 AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate >= @FromDate AND b.transdate <= @ToDate 
			AND b.custid = @CustID
			AND sbt.ProductID IN (3, 5, 27)
			AND sbt.EventType = 1
			AND b.statusID IN (0, 1)

		UNION
		SELECT
			r.sporttype,
			@Username AS UserName,
			b.bettype,
			r.LeagueID,
			b.refno,
			b.transid,
			ISNULL(b.BetID, 0),
			CONVERT(VARCHAR(50), o.RacerNum) AS matchcode,
			b.oddsid AS Race,
			b.WinLostDate AS EventDate,
			o.RacerID AS homeID,
			0 AS awayID,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
				ELSE b.status
			END AS status,
			0 AS SettlementStatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.discount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			CONVERT(BIT,0) AS IsNeutral,
			b.oddstype,
			CONVERT(VARCHAR(20), r.EventTime) AS ShowTime,
			0 AS matchid,
			'' AS BetCheck,
			'' AS TransDesc,
			-1 AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate >= @FromDate AND b.transdate <= @ToDate
			AND b.custid = @CustID 
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
			AND b.statusID IN (0, 1)
	END

	-- Bitcoin
	IF @ShowBTC = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			m.SportType,
			@Username AS UserName,
			b.bettype,
			m.League3rdId AS LeagueId,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			'' AS MatchCode,
			'' AS Race,
			m.EndTime AS EventDate,
			0 AS HomeId,
			0 AS AwayId,
			b.hdp1,
			0 AS Hdp2,
			b.odds,
			0 AS MOdds,
			b.status,
			0 AS SettlementStatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.discount,
			0 AS LiveIndicator,
			0 AS LiveHomeScore,
			0 AS LiveAwayScore,
			b.ip,
			CONVERT(BIT, 0) AS IsNeutral,
			b.oddstype,
			'' AS ShowTime,
			b.matchid,
			'' AS BetCheck,
			'' AS TransDesc,
			-1 AS BetdaqId,
			b.ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON m.Match3rdId = b.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE b.transdate BETWEEN @FromDate AND @ToDate
			AND b.custid = @CustId
			AND b.statusID IN (0, 1)
			AND sbt.ProductID IN (69)
	END

	-- Keno, Lottery, Virtual Games, Table Games, Indo 4D, Happy 5 Linked Games, Sports Lottery, Virtual Sports 3 (translog)
	IF @ShowKN = 1 OR @ShowLT = 1 OR @ShowVRG = 1 OR @ShowTG = 1 OR @ShowI4D = 1 OR @ShowNG = 1 OR @ShowSLT = 1 OR @ShowVS3 = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			CASE
				WHEN sbt.ProductID = 8 THEN 202
				WHEN sbt.ProductID = 28 THEN 220
				WHEN sbt.ProductID IN (3, 38, 40, 43, 49, 63) THEN t.productid
				ELSE 0
			END AS SportType,
			@Username AS UserName,
			t.gameid AS BetType,
			0 AS LeagueId,
			t.translogid AS RefNo,
			t.translogid AS TransId,
			0 AS BetId,
			'' AS MatchCode,
			'' AS Race,
			'' AS EventDate,
			0 AS HomeId,
			0 AS AwayId,
			0 AS hdp1,
			0 AS hdp2,
			t.odds,
			0 AS MOdds,
			t.status,
			0 AS SettlementStatus,
			t.stake,
			t.actual_stake,
			t.transdate,
			'' AS BetTeam,
			t.discount,
			0 AS LiveIndicator,
			0 AS LiveHomeScore,
			0 AS LiveAwayScore,
			t.ip,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS OddsType,
			'' AS ShowTime,
			0 AS MatchId,
			CASE
				WHEN sbt.ProductId = 8 THEN ISNULL(t.custom2, '')
				WHEN sbt.ProductId IN (3, 38, 63) THEN ISNULL(t.Gameid3rd, '')
				WHEN sbt.ProductID IN (49) THEN ISNULL(t.custom1, '')
				ELSE '' 
			END AS BetCheck,
			CASE
				WHEN sbt.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN ISNULL(t.transdesc, '')
				ELSE ''
			END AS TransDesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM 
			dbo.translog AS t WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON t.gameID = sbt.Bettype
		WHERE
			t.transdate BETWEEN @FromDate AND @ToDate
			AND t.custid = @CustID
			AND t.statusID IN (0, 1)
			AND sbt.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63)
			AND sbt.EventType = 0
	END

	-- RNG Casino Single Wallet, Macau Games, Pragmatic Casino, Card Club, Spadegaming, Saba.club, PG Soft, Joker, Habanero, Vgaming, CG, AdvantPlay, AdvantPlay Mini
	-- MaxGame, Jili
	IF (@ShowCS = 1 OR @ShowVB = 1 OR @ShowPP = 1 OR @ShowCC = 1 OR @ShowSG = 1 OR @ShowSBC = 1 OR @ShowPGS = 1 OR @ShowJK = 1
		OR @ShowHB = 1 OR @ShowVGA = 1 OR @ShowCG = 1 OR @ShowAP = 1 OR @ShowAPM = 1 OR @ShowMXG = 1 OR @ShowJIG = 1)
		AND EXISTS (SELECT 1 FROM dbo.bettransRnG WITH (NOLOCK) WHERE custid = @CustId AND statusID IN (0, 1))
	BEGIN
		-- Yesterday and today running ticket
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			CASE
				WHEN sbt.ProductID IN (6, 34, 36, 42, 55, 56, 60, 61, 62, 66, 67, 68, 75) THEN b.matchid
				WHEN sbt.ProductID = 22 THEN 212
				WHEN sbt.ProductID = 32 THEN 248
				ELSE 0
			END AS Sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,
			b.transid,
			0 AS BetID,
			'' AS matchcode,
			'' AS Race,
			'' AS EventDate,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			'Running' AS Status,
			0 AS SettlementStatus,
			SUM(brng.stake) AS Stake,
			SUM(brng.actual_stake) AS Actual_Stake,
			b.transdate,
			'' AS betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS oddstype,
			'' AS ShowTime,
			0 AS matchid,
			'' AS betcheck,
			b.transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM 
			dbo.bettransRnG AS brng WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE
			b.transdate BETWEEN @FromDate AND @ToDate
			AND b.winlostdate BETWEEN @Yesterday AND @Today
			AND brng.custid = @CustId
			AND (sbt.ProductID IN (22, 32, 34, 36, 42, 55, 56, 60, 61, 62, 66, 67, 68, 75)
				OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
			AND sbt.EventType = 0
			AND brng.statusID IN (0, 1)
		GROUP BY
			b.transid,
			ISNULL(b.betid, 0),
			b.bettype,
			b.refno,
			b.transdate,
			b.discount,
			b.ip,
			b.currency,
			b.matchid,
			b.transdesc,
			sbt.ProductID
	END

	-- AG Casino, AllBet, SA Gaming, Sexy Gaming, WM Live Casino, Big Gaming, FGG, YeeBet
	IF (@ShowAGC = 1 OR @ShowAB = 1 OR @ShowSAG = 1 OR @ShowSXG = 1 OR @ShowWM = 1 OR @ShowBGG = 1 OR @ShowFGGL = 1 OR @ShowYB = 1)
		AND EXISTS (SELECT 1 FROM dbo.bettransLC WITH (NOLOCK) WHERE custid = @CustId AND statusID IN (0, 1))
	BEGIN
		-- Yesterday and today running ticket
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			CASE
				WHEN sbt.ProductID = 11 THEN 250
				WHEN sbt.ProductID = 21 THEN 211
				ELSE b.matchid
			END AS Sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,
			b.transid,
			0 AS BetID,
			'' AS matchcode,
			'' AS Race,
			'' AS EventDate,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			'Running' AS Status,
			0 AS SettlementStatus,
			SUM(blc.stake) AS Stake,
			SUM(blc.actual_stake) AS Actual_Stake,
			b.transdate,
			'' AS betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS oddstype,
			'' AS ShowTime,
			0 AS matchid,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM 
			dbo.bettransLC AS blc WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
		WHERE
			b.transdate BETWEEN @FromDate AND @ToDate
			AND b.winlostdate BETWEEN @Yesterday AND @Today		-- yesterday and today
			AND blc.custid = @CustId
			AND sbt.ProductID IN (11, 21, 39, 45, 51, 57, 70, 76)
			AND sbt.EventType = 0
			AND blc.statusID IN (0, 1)
		GROUP BY
			b.transid,
			ISNULL(b.betid, 0),
			b.bettype,
			b.refno,
			b.transdate,
			b.discount,
			b.ip,
			b.currency,
			sbt.productID,
			b.matchid
	END

	IF @ExcludeFreeBet = 1
	BEGIN
		-- Exclude Saba.club Free Bet
		DELETE FROM #BetListSelRunningByDateMem
		WHERE SportType = 150
	END

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM #BetListSelRunningByDateMem WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode		BIGINT,
			TransId		BIGINT,
			Stake		MONEY
		)

		-- Prepare temp table
		INSERT INTO @RefCodeTmp
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake
		FROM #BetListSelRunningByDateMem
		WHERE RefCode <> 0
		GROUP BY RefCode
		HAVING COUNT(*) > 1

		IF EXISTS (SELECT 1 FROM @RefCodeTmp)
		BEGIN
			-- Update data for summmary ticket
			UPDATE b
			SET
				b.Stake = r.Stake,
				b.WalletType = 0
			FROM #BetListSelRunningByDateMem AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE #BetListSelRunningByDateMem
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE #BetListSelRunningByDateMem
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE #BetListSelRunningByDateMem
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- set totalrows
	SELECT @TotalRows = COUNT(1)
	FROM #BetListSelRunningByDateMem

	DECLARE @Currency	INT,
		@ExRate			FLOAT

	SELECT @Currency = currency
	FROM CustDB.dbo.Customer WITH (NOLOCK)
	WHERE custid = @CustId

	-- Get exchange rate
	SELECT @ExRate = e.Rate
	FROM dbo.SiteDB_Lrf_f_GetExchangeRate(DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), @BaseCurrency, '') AS e
	WHERE e.ExchangeId = @Currency

	-- select to paging
	SELECT
		a.SportType,
		a.Username,
		a.BetType,
		a.LeagueId,
		a.RefNo,
		a.TransId,
		a.BetId,
		a.MatchCode,
		a.Race,
		a.EventDate,
		a.HomeId,
		a.AwayId,
		a.Hdp1,
		a.Hdp2,
		a.Odds,
		a.Modds,
		a.Status,
		a.SettlementStatus,
		a.Stake * ISNULL(@ExRate, 1) AS Stake,
		a.Actual_Stake * ISNULL(@ExRate, 1) AS Actual_Stake,
		a.TransDate,
		a.BetTeam,
		a.Discount,
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.Ip,
		a.IsNeutral,
		a.OddsType,
		a.ShowTime,
		a.MatchId,
		a.BetCheck,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.OriginalStake * ISNULL(@ExRate, 1) AS OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode,
		a.OddsSpread,
		@Currency AS Currency
	FROM
		(	SELECT
				ROW_NUMBER() OVER(ORDER BY TransDate DESC) AS RowNum,
				*
			FROM #BetListSelRunningByDateMem
		) AS a
	WHERE a.RowNum BETWEEN (((@PageIndex - 1) * @PageSize) + 1) AND (@PageSize * @PageIndex)

	-- Get sub tickets
	DECLARE @BetListDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(20)
	);

	-- Virtual Sports
	IF EXISTS (	SELECT 1
				FROM #BetListSelRunningByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE sbt.ProductId = 5 AND sbt.EventType = 3)
	BEGIN
		INSERT INTO @BetListDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake * ISNULL(@ExRate, 1) AS Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			'' AS betteam
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #BetListSelRunningByDateMem AS b ON bm.refno = b.RefNo
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
			AND sbtm.ProductID = 5
			AND sbtm.EventType = 3
	END

	SELECT * FROM @BetListDetail
	ORDER BY RefNo ASC

	DROP TABLE #BetListSelRunningByDateMem
END
GO
