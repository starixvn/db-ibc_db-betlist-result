USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossByMatch]
	@AgentList		VARCHAR(MAX),
	@MatchId		INT,
	@PageSize		INT = 1000,
	@PageIndex		INT = 1,
	@ShowSB			BIT = 0,
	@ShowBA			BIT = 0,
	@ShowLC			BIT = 0,
	@ShowVS			BIT = 0,
	@LiveIndicator	INT = 1
AS

/*
	Created: 20120111@Henry
	Task: Betlist
	DB: DBEXT.bodb02
	Original:[Lrf_BetList_SelWinlostByMatch]
	Revisions:
		Get all tickets for a match
		- 20120214@Jim: change to use table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120724@Jim: add playercomm value
		- 20120820@Jim: add livecasino
		- 20120913@Jim: add virtual sport
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20130411@Jim: support base currency USD
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130625@Jim: support to view currency UUS 
		- 20140602@Hannah: Separate Live/ Non - Live data in Live Report
		- 20140630@Hannah: offer BetRadar and Sporting Solution 
		- 20140925@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150124@Winnie: add base currency GBP
		- 20150413@Winnie: Apply spottype bettype matrix & add 60 bettype betradar
		- 20150608@Edward: Exclude 3 transactions SOLD/BOUGHT/BetTrade Commission of BetTrade
		- 20150609@Edward: Support Microgaming
		- 20150922@Kos: Don't support Microgaming anymore
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160714@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20161005@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170301@Kos: Support sub licensees [#Redmine: 71679]
		- 20170303@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]

	Param's Explanation: 
		@LiveIndicator : indicate that whether the report will get live data or not
			+ 0: Non - Live data only
			+ 1: Live data only
			+ 2: All
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
	DECLARE @SportBettype TABLE(ProductID INT, Bettype INT, EventType INT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID <> 1 OR Bettype NOT IN (901, 902, 903, 904)

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	CREATE TABLE #Data (
		SportType		INT,
		Username		NVARCHAR(50),
		CustId			INT,
		BetType			INT,
		LeagueId		INT,
		TransId			BIGINT,
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			VARCHAR(50),
		LiveIndicator	INT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		MatchId			INT,
		Ip				NVARCHAR(30),
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		OddsType		INT,
		BetId			BIGINT,
		Currency		SMALLINT,
		RefNo			BIGINT,
		ShowTime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300)
	)

	IF EXISTS(SELECT TOP 1 1 FROM dbo.match WITH(NOLOCK) WHERE matchid = @MatchID)
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT TOP(@RowEnd)
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid, 
				b.ip,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK,INDEX=IXU_transid)
				INNER JOIN bodb_licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.matchid = @MatchId 
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND sbt.ProductID = 1
				AND sbt.EventType != 0 
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.liveindicator = 1)
					OR (@LiveIndicator = 2))
			ORDER BY
				b.status,
				b.transid
		
			--BA for parlay
			INSERT INTO #Data
			SELECT TOP(@RowEnd)
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid, 
				b.ip,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK,INDEX=IXU_transid)
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.matchid = @MatchId
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
					OR (@LiveIndicator = 1 AND b.livehomescore = 1)
					OR (@LiveIndicator = 2))
			ORDER BY
				b.status,
				b.transid
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT TOP(@RowEnd)
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) winlost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				b.ip,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.matchid = @MatchId
				AND sbt.ProductID = 1
				AND sbt.EventType != 0
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.liveindicator = 1)
					OR (@LiveIndicator = 2))
			ORDER BY
				b.status,
				b.transid

			-- Parlay
			INSERT INTO #Data
			SELECT TOP(@RowEnd)
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS WinLost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid, 
				b.ip,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.OddsType,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.matchid = @MatchId
				AND sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
					OR (@LiveIndicator = 1 AND b.livehomescore = 1)
					OR (@LiveIndicator = 2))
			ORDER BY
				b.status,
				b.transid
		END

		-- Live Casino, Virtual Sports
		IF @ShowLC = 1 OR @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT TOP(@RowEnd)
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS WinLost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid, 
				b.ip,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				CASE
					WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime, '')
					WHEN sbt.ProductID = 5 THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE '' 
				END AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE
				b.matchid = @MatchId
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (111, 112, 113)
				AND ((@ShowVS = 1 AND sbt.ProductID = 5 AND sbt.EventType = 1)
					OR (@ShowLC = 1 AND sbt.ProductID = 4))
				AND ((@LiveIndicator = 0 AND b.liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.liveindicator = 1)
					OR (@LiveIndicator = 2))
			ORDER BY
				b.status,
				b.transid
		END
	END
	ELSE
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT TOP(@RowEnd)
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				b.ip,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @TempAg AS t ON b.recommend = t.custid
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE
				b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.matchid = @MatchId
				AND b.statusID IN (111, 112, 113)
				AND tpositiontaking = 0
				AND sbt.ProductID = 1
				AND sbt.EventType != 0
				AND ((@LiveIndicator = 0 AND b.liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.liveindicator = 1)
					OR (@LiveIndicator = 2))
			ORDER BY
				b.status,
				b.transid

			-- BA for parlay
			INSERT INTO #Data
			SELECT TOP(@RowEnd)
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid, 
				b.ip,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @TempAg AS t ON b.recommend = t.custid
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE
				b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.matchid = @MatchId
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking = 0
				AND sbt.ProductID = 1
				AND sbt.EventType = 0
				AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
					OR (@LiveIndicator = 1 AND b.livehomescore = 1)
					OR (@LiveIndicator = 2))
			ORDER BY
				b.status,
				b.transid
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT TOP(@RowEnd)
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS WinLost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				b.ip,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN @TempAg AS t ON b.recommend = t.custid
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE
				b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.matchid = @MatchId
				AND sbt.ProductID = 1
				AND sbt.EventType != 0
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.liveindicator = 1)
					OR (@LiveIndicator = 2))
			ORDER BY
				b.status,
				b.transid

			-- Parlay
			INSERT INTO #Data
			SELECT TOP(@RowEnd)
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS WinLost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid, 
				b.ip,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @TempAg AS t ON b.recommend = t.custid
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON sbt.Bettype = b.bettype
			WHERE
				b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.matchid = @MatchId
				AND sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
					OR (@LiveIndicator = 1 AND b.livehomescore = 1)
					OR (@LiveIndicator = 2))
			ORDER BY
				b.status,
				b.transid
		END

		-- Live Casino, Virtual Sports
		IF @ShowLC = 1 OR @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT TOP(@RowEnd)
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS WinLost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid, 
				b.ip,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				CASE
					WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime, '')
					WHEN sbt.ProductID = 5 THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE ''
				END AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN @TempAg AS t ON b.recommend = t.custid
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE
				b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.matchid = @MatchId
				AND b.statusID IN (111, 112, 113)
				AND ((@ShowVS = 1 AND sbt.ProductID = 5 AND sbt.EventType = 1)
					OR (@ShowLC = 1 AND sbt.ProductID = 4))
				AND ((@LiveIndicator = 0 AND b.liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.liveindicator = 1)
					OR (@LiveIndicator = 2))
			ORDER BY
				b.status,
				b.transid
		END
	END

	DECLARE @Fromdate DATETIME
	DECLARE @Todate DATETIME

	SELECT @Fromdate = MIN(winlostdate),
		@Todate = MAX(winlostdate) 
	FROM #Data

	CREATE NONCLUSTERED INDEX IDX_Index_data ON #Data(Currency)

	SELECT *
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

	SELECT A.* 
	FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.transid) AS RowNum,
				b.*,
				SUBSTRING(c.username2,  CHARINDEX('$',c.username2) + 1, LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
				-- USD
				b.Stake			* e.USD AS StakeUSD,
				b.WinLost		* e.USD AS WinLostUSD,
				b.LicenseeWL	* e.USD AS LicenseeWLUSD,
				b.Comm			* e.USD AS CommUSD,
				b.PlayerComm	* e.USD AS PlayerCommUSD,
				-- EUR
				b.Stake			* e.EUR AS StakeEUR,
				b.WinLost		* e.EUR AS WinLostEUR,
				b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
				b.Comm			* e.EUR AS CommEUR,
				b.PlayerComm	* e.EUR AS PlayerCommEUR,
				-- GBP
				b.Stake			* e.GBP AS StakeGBP,
				b.WinLost		* e.GBP AS WinLostGBP,
				b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
				b.Comm			* e.GBP AS CommGBP,
				b.PlayerComm	* e.GBP AS PlayerCommGBP
			FROM #Data AS b
				INNER JOIN dbo.Customer AS c (NOLOCK) ON b.CustId = c.custid
				INNER JOIN #TempExchange AS e ON b.Currency = e.exchangeID AND b.WinLostDate = e.exchangeDate
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	-- Get sub tickets
	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		StakeEUR		MONEY,
		StakeUSD		MONEY,
		StakeGBP		MONEY
	)

	IF EXISTS (	SELECT TOP 1 1
				FROM #Data AS b
					INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
				WHERE sbt.ProductID = 4)
	BEGIN
		IF EXISTS(SELECT TOP 1 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchID)
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.betteam,
				bg.stake * e.EUR,
				bg.stake * e.USD,
				bg.stake * e.GBP
			FROM dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN #Data AS b ON bg.refno = b.RefNo AND bg.custid = b.CustId
				INNER JOIN #TempExchange AS e ON b.Currency = e.exchangeID AND b.WinLostDate = e.exchangeDate
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
			WHERE sbt.ProductID = 4 AND sbtg.ProductId = 4
		END

		IF EXISTS(SELECT TOP 1 1 FROM dbo.match14 WITH (NOLOCK) WHERE matchid = @MatchID)
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.Betteam,
				bg.stake * e.EUR,
				bg.stake * e.USD,
				bg.stake * e.GBP
			FROM dbo.bettransg14 AS bg WITH (NOLOCK)
				INNER JOIN #Data AS b ON bg.refno = b.RefNo AND bg.custid = b.CustId
				INNER JOIN #TempExchange AS e ON b.Currency = e.exchangeID AND b.WinLostDate = e.exchangeDate
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
			WHERE sbt.ProductID = 4 AND sbtg.ProductId = 4
		END
	END

	SELECT DISTINCT * FROM @BettransDetail
	ORDER BY RefNo, Bettype

	DROP TABLE #Data
	DROP TABLE #TempExchange
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossByMatch] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LiveReport_SelWinlossByMatch] TO [vnteam]