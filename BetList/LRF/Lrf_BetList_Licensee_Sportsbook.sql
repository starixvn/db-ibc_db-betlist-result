/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Licensee_Sportsbook]
	@AgentList			VARCHAR(MAX),
	@Username			VARCHAR(50)		= '',
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@Product			VARCHAR(100)	= '',
	@SportType			TINYINT			= 0,
	@BetType			SMALLINT		= 0,
	@LeagueId			INT				= 0,
	@MatchId			INT				= 0,
	@LeagueGroupIds		VARCHAR(200)	= '',
	@BaseCurrency		VARCHAR(12),
	@ConvertToBaseCur	BIT				= 0,	-- Convert to base currency or not
	@StatusIdList		VARCHAR(50)		= '',
	@LiveIndicator		VARCHAR(10)		= '0,1,2',
	@PlatformType		VARCHAR(100)	= 'All',
	@CustomerClass		VARCHAR(MAX)	= 'All',
	@FullCustomerClass	VARCHAR(MAX)	= 'All',
	@OddsGroup			VARCHAR(100)	= 'All',
	@Ip					VARCHAR(45)		= '',
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@Sort				NVARCHAR(50)	= N'Transid ASC',
	@TotalRows			INT				= 0 OUTPUT,
	@SumStake			MONEY			= 0 OUTPUT,
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Multiple Customer Bet List - Sportsbook and BA
	DB: DBEXT.bodb02
	Original: Lrf_BetList_Licensee
	Parameter's Explanation:
		- @StatusIdList:
			- 101: Reject
			- 102: Void (not include Abnormal Bets)
			- 103: Refund
			- 111: Draw
			- 112: Won
			- 113: Lose
			- 99: Abnormal Bets
			- 2: Delay Payout
		- @LiveIndicator:
			- 0 : Non-live
			- 1 : Live
			- 2 : Mix Non Live & Live

	Revisions:
		- 20190214@Kos: Betting Ticket Center phase 3b [Redmine: #108221]
		- 20190313@Kos: Change param @LiveIndicator from TINYINT to VARCHAR(10) [Redmine: #108717]
					- Add new param @Username, @ConvertToBaseCur
		- 20190422@Kos: Enhance performance for searching too many members [Redmine: #112313]
		- 20190426@Kos: Support base currency INH [Redmine: #112603]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190829@Kos: Support PH AIO 4b [Redmine: #118300]
		- 20200425@Kos: Support status Delay Payout [Redmine: #132629]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]
		- 20201210@Kos: Exclude bettype 999 Odds Spread Adjustment [Redmine: #142532]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210316@Kos: Support Cricket AIO [Redmine: #148962]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211104@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
		- 20211126@Kos: Support Parlay Abnormal Bet [Redmine: #163900]
		- 20211215@Kos: Hotfix - Show Casino tickets when choosing Delayed Payout [Redmine: #166109]
		- 20211220@Kos: Support new Cash Out [Redmine: #165160]
		- 20220113@Kos: Support new 3rd result API [Redmine: #166047]
		- 20220215@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20220216@Kos: Support search by IP [RedmineID: #166079]
		- 20220428@Kos: Support Bitcoin [Redmine: #160160]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20230404@Kos: Extend betfrom length [Redmine: #178059]
		- 20230511@Kos: Support Saba Sports [Redmine: 183841]
					- Add new input params @LeagueGroupIds, @PlatformType, @CustomerClass, @OddsGroup
		- 20230703@Kos: Support Saba Tennis [RedmineID: #190465]
		- 20231225@Kos: Hide Saba text for Jollysports licensees [Redmine: 198697]
		- 20240207@Kos: Hotfix - No data when filtering player has Risk Level Uncategorized [RedmineID: #200913]
					- Add new input param @FullCustomerClass VARCHAR(MAX)
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_TempAg ON #TempAg (CustId)

	DECLARE @HasError BIT = 0

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SET @HasError = 1
	END CATCH

	-- Get Saba sport type list
	DECLARE @SabaSportType TABLE (SportType SMALLINT, LeagueGroupIdList VARCHAR(200))

	INSERT INTO @SabaSportType
	SELECT 1, '42,74'		-- Saba Soccer
	UNION SELECT 1, '113'	-- Saba Soccer PinGoal
	UNION SELECT 2, '42'	-- Saba Basketball
	UNION SELECT 2, '122'	-- Saba Basketball PinGoal
	UNION SELECT 50, '42'	-- Saba Cricket
	UNION SELECT 1, '108'	-- Saba Futsal
	UNION SELECT 43, '151'	-- Saba E-Sports PinGoal
	UNION SELECT 5, '42'	-- Saba Tennis

	CREATE TABLE #Data (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Recommend			INT,
		Currency			SMALLINT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		Status				NVARCHAR(10),
		StatusId			TINYINT,
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(4),
		LeagueId			INT,
		LeagueGroupId		SMALLINT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		SiteId				VARCHAR(20),
		Product				VARCHAR(30),
		WhTicket			TINYINT
	)

	CREATE TABLE #PagingData (
		RowNum				INT,
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Recommend			INT,
		Currency			SMALLINT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		Status				NVARCHAR(10),
		StatusId			TINYINT,
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(4),
		LeagueId			INT,
		LeagueGroupId		SMALLINT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		SiteId				VARCHAR(20),
		Product				VARCHAR(30),
		WhTicket			TINYINT
	)

	DECLARE @Detail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10)
	)

	CREATE TABLE #ExchangeRate (
		ExchangeId					INT,
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	IF @HasError = 0
	BEGIN
		DECLARE @ProductList	VARCHAR(10),
			@ShowSB				BIT				= 0

		IF @Product IN ('BA', 'CO')
		BEGIN
			SET @ProductList = 'SB'
		END
		ELSE
		BEGIN
			SET @ProductList = @Product
		END

		IF ',' + @Product + ',' LIKE '%,SB,%'
			SET @ShowSB = 1

		-- Get SportBettypeMatrix
		CREATE TABLE #SportBettype (ProductId TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

		CREATE CLUSTERED INDEX IX_BetType ON #SportBettype (BetType)

		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		INSERT INTO #SportBettype
		SELECT ProductID, BetType, EventType, SubProduct
		FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)
		WHERE (@BetType = 0
				OR BetType IN (	SELECT @BetType
								UNION SELECT Bettype FROM dbo.f_GroupBettype() WHERE GroupTypeId = @BetType))
			AND BetType <> 999

		DECLARE @OriginalStatusIdList	VARCHAR(50)

		SET @OriginalStatusIdList = @StatusIdList

		IF ',' + @StatusIdList + ',' LIKE '%,99,%'		-- Abnormal Bet
		BEGIN
			SET @StatusIdList = @StatusIdList + ',102'
		END

		IF ',' + @StatusIdList + ',' LIKE '%,2,%'		-- Delay Payout
		BEGIN
			SET @StatusIdList = @StatusIdList + ',111,112,113'
		END

		CREATE TABLE #TempCust (CustId INT PRIMARY KEY, CustomerClass SMALLINT)

		IF @Username IS NOT NULL AND @Username <> ''
		BEGIN
			INSERT INTO #TempCust (CustId, CustomerClass)
			SELECT
				c.custid,
				ci.CustomerClass
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON c.recommend = a.CustId
				LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = c.custid
			WHERE c.roleid = 1
				AND (c.username LIKE + '%' + @Username + '%'
					OR c.username2 LIKE + '%$%' + @Username + '%')
				AND (@OddsGroup = 'All'
					OR ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%')

			IF @CustomerClass <> 'All'
			BEGIN
				DELETE #TempCust
				WHERE 1 <> CASE
								WHEN ',' + @CustomerClass + ',' LIKE '%,0,%' AND CustomerClass IS NULL THEN 1
								WHEN ',' + @CustomerClass + ',' LIKE '%,0,%'
									AND ',' + @FullCustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
								WHEN ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
								ELSE 0
							END
			END
		END

		DECLARE @NumOfMem	INT = 0

		SELECT @NumOfMem = COUNT(1) FROM #TempCust

		DECLARE @MatchSportType	SMALLINT,
			@ParentId			INT

		SELECT
			@MatchSportType = sporttype,
			@ParentId = ParentID
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId AND eventdate > @MoveBetsDay

		IF @MatchSportType IS NULL
		BEGIN
			SELECT
				@MatchSportType = sporttype,
				@ParentId = ParentID
			FROM dbo.match14 WITH (NOLOCK)
			WHERE matchid = @MatchId
		END

		DECLARE @Match TABLE(MatchId INT)

		IF @MatchSportType = 50 AND @ParentId IS NULL	-- Cricket, parent match
		BEGIN
			INSERT INTO @Match
			SELECT DISTINCT MatchId
			FROM dbo.match WITH (NOLOCK)
			WHERE ParentID = @MatchId
				AND sporttype = @MatchSportType
				AND eventdate BETWEEN @FromDate AND @ToDate
				AND ChildMatchType = 200
			UNION
			SELECT DISTINCT MatchId
			FROM dbo.match14 WITH (NOLOCK)
			WHERE ParentID = @MatchId
				AND sporttype = @MatchSportType
				AND eventdate BETWEEN @FromDate AND @ToDate
				AND ChildMatchType = 200
		END

		DECLARE @TempToDate	SMALLDATETIME,
			@TempFromDate	SMALLDATETIME

		IF @Username IS NULL OR @Username = '' OR @NumOfMem > 5000		-- Licensee level (not input username of number of searched member > 5000)
		BEGIN
			-- Bettrans range
			IF @ToDate > @MoveBetsDay
			BEGIN
				IF @FromDate <= @MoveBetsDay
					SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
				ELSE
					SET @TempFromDate = @FromDate

				IF @SportType = 0 AND @LeagueId = 0
				BEGIN
					INSERT INTO #Data (
						TransId,
						RefNo,
						CustId,
						Recommend,
						Currency,
						BetType,
						BetId,
						BetTeam,
						Hdp1,
						Hdp2,
						OddsType,
						Odds,
						MOdds,
						OddsSpread,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						Comm,
						PlayerComm,
						Status,
						StatusId,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						BetCheck,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WalletType,
						RefCode,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						b.betid,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						CASE
							WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
							ELSE - (b.winlost - b.actual_stake)
						END AS LiceseeWL,
						b.comm,
						b.playercomm,
						b.status,
						b.statusID,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.betcheck,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						b.WalletType,
						ISNULL(b.RefCode, 0),
						1 AS WhTicket
					FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN #TempAg AS a ON b.recommend = a.CustId
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
					WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND b.bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
						AND b.bettype NOT BETWEEN 801 AND 899
						AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
							OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
						AND (@MatchId = 0
							OR b.matchid = @MatchId
							OR b.matchid IN (SELECT MatchId FROM @Match))
						AND 1 = CASE
									WHEN s.ProductID = 1 THEN
										CASE
											WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
											WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
											WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
											ELSE 0
										END
									ELSE 1
								END
				END
				ELSE
				BEGIN
					IF @BetType <> 10
					BEGIN
						INSERT INTO #Data (
							TransId,
							RefNo,
							CustId,
							Recommend,
							Currency,
							BetType,
							BetId,
							BetTeam,
							Hdp1,
							Hdp2,
							OddsType,
							Odds,
							MOdds,
							OddsSpread,
							Stake,
							Actual_Stake,
							WinLost,
							LicenseeWL,
							Comm,
							PlayerComm,
							Status,
							StatusId,
							TransDate,
							WinLostDate,
							LiveIndicator,
							LiveHomeScore,
							LiveAwayScore,
							Ip,
							BetFrom,
							MatchId,
							BetCheck,
							TransDesc,
							BetdaqId,
							ExtraInfo,
							WalletType,
							RefCode,
							WhTicket)
						SELECT
							b.transid,
							b.refno,
							b.custid,
							b.recommend,
							b.currency,
							b.bettype,
							b.betid,
							b.betteam,
							b.hdp1,
							b.hdp2,
							b.oddstype,
							b.odds,
							b.modds,
							b.oddsspread,
							b.stake,
							b.actual_stake,
							(b.winlost - b.actual_stake) AS WinLost,
							CASE
								WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
								ELSE - (b.winlost - b.actual_stake)
							END AS LiceseeWL,
							b.comm,
							b.playercomm,
							b.status,
							b.statusID,
							b.transdate,
							b.winlostdate,
							b.liveindicator,
							b.livehomescore,
							b.liveawayscore,
							b.ip,
							b.betfrom,
							b.matchid,
							b.betcheck,
							b.transdesc,
							b.betdaqid,
							b.ExtraInfo,
							b.WalletType,
							ISNULL(b.RefCode, 0),
							1 AS WhTicket
						FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
							INNER JOIN #TempAg AS a ON b.recommend = a.CustId
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
							LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
							LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
							LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
						WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
							AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
							AND b.bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
							AND b.bettype NOT BETWEEN 801 AND 899
							AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
								OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
							AND (@SportType = 0
								OR (m.sporttype = @SportType AND s.EventType = 1)
								OR (l.sporttype = @SportType AND b.bettype = 10)
								OR (b.matchid = @SportType AND s.ProductId IN (63))
								OR (m3rd.SportType = @SportType AND s.EventType = 5))
							AND (@LeagueId = 0
								OR (m.leagueid = @LeagueId AND s.EventType = 1)
								OR (o.leagueid = @LeagueId AND b.bettype = 10))
							AND (@MatchId = 0
								OR b.matchid = @MatchId
								OR b.matchid IN (SELECT MatchId FROM @Match))
							AND 1 = CASE
										WHEN s.ProductID = 1 THEN
											CASE
												WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
												WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
												WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
												ELSE 0
											END
										ELSE 1
									END
					END
					ELSE
					BEGIN
						INSERT INTO #Data (
							TransId,
							RefNo,
							CustId,
							Recommend,
							Currency,
							BetType,
							BetId,
							BetTeam,
							Hdp1,
							Hdp2,
							OddsType,
							Odds,
							MOdds,
							OddsSpread,
							Stake,
							Actual_Stake,
							WinLost,
							LicenseeWL,
							Comm,
							PlayerComm,
							Status,
							StatusId,
							TransDate,
							WinLostDate,
							LiveIndicator,
							LiveHomeScore,
							LiveAwayScore,
							Ip,
							BetFrom,
							MatchId,
							BetCheck,
							TransDesc,
							BetdaqId,
							ExtraInfo,
							WalletType,
							RefCode,
							WhTicket)
						SELECT
							b.transid,
							b.refno,
							b.custid,
							b.recommend,
							b.currency,
							b.bettype,
							b.betid,
							b.betteam,
							b.hdp1,
							b.hdp2,
							b.oddstype,
							b.odds,
							b.modds,
							b.oddsspread,
							b.stake,
							b.actual_stake,
							(b.winlost - b.actual_stake) AS WinLost,
							CASE
								WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
								ELSE - (b.winlost - b.actual_stake)
							END AS LiceseeWL,
							b.comm,
							b.playercomm,
							b.status,
							b.statusID,
							b.transdate,
							b.winlostdate,
							b.liveindicator,
							b.livehomescore,
							b.liveawayscore,
							b.ip,
							b.betfrom,
							b.matchid,
							b.betcheck,
							b.transdesc,
							b.betdaqid,
							b.ExtraInfo,
							b.WalletType,
							ISNULL(b.RefCode, 0),
							1 AS WhTicket
						FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
							INNER JOIN #TempAg AS a ON b.recommend = a.CustId
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
							LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
						WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
							AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
							AND b.bettype = 10
							AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
							AND (@SportType = 0 OR l.sporttype = @SportType)
							AND (@LeagueId = 0 OR o.leagueid = @LeagueId)
							AND (@MatchId = 0
								OR b.matchid = @MatchId
								OR b.matchid IN (SELECT MatchId FROM @Match))
							AND 1 = CASE
										WHEN s.ProductID = 1 THEN
											CASE
												WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
												WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
												WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
												ELSE 0
											END
										ELSE 1
									END
					END
				END
			END

			-- Bettrans14 range
			IF @FromDate <= @MoveBetsDay
			BEGIN
				IF @ToDate > @MoveBetsDay
					SET @TempToDate = @MoveBetsDay
				ELSE
					SET @TempToDate = @ToDate

				IF @SportType = 0 AND @LeagueId = 0
				BEGIN
					INSERT INTO #Data (
						TransId,
						RefNo,
						CustId,
						Recommend,
						Currency,
						BetType,
						BetId,
						BetTeam,
						Hdp1,
						Hdp2,
						OddsType,
						Odds,
						MOdds,
						OddsSpread,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						Comm,
						PlayerComm,
						Status,
						StatusId,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						BetCheck,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WalletType,
						RefCode,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						b.betid,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						CASE
							WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
							ELSE - (b.winlost - b.actual_stake)
						END AS LiceseeWL,
						b.comm,
						b.playercomm,
						b.status,
						b.statusID,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.betcheck,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						b.WalletType,
						ISNULL(b.RefCode, 0),
						2 AS WhTicket
					FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN #TempAg AS a ON b.recommend = a.CustId
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
					WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND b.bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
						AND b.bettype NOT BETWEEN 801 AND 899
						AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
							OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
						AND (@MatchId = 0
							OR b.matchid = @MatchId
							OR b.matchid IN (SELECT MatchId FROM @Match))
						AND 1 = CASE
									WHEN s.ProductID = 1 THEN
										CASE
											WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
											WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
											WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
											ELSE 0
										END
									ELSE 1
								END
				END
				ELSE
				BEGIN
					IF @BetType <> 10
					BEGIN
						INSERT INTO #Data (
							TransId,
							RefNo,
							CustId,
							Recommend,
							Currency,
							BetType,
							BetId,
							BetTeam,
							Hdp1,
							Hdp2,
							OddsType,
							Odds,
							MOdds,
							OddsSpread,
							Stake,
							Actual_Stake,
							WinLost,
							LicenseeWL,
							Comm,
							PlayerComm,
							Status,
							StatusId,
							TransDate,
							WinLostDate,
							LiveIndicator,
							LiveHomeScore,
							LiveAwayScore,
							Ip,
							BetFrom,
							MatchId,
							BetCheck,
							TransDesc,
							BetdaqId,
							ExtraInfo,
							WalletType,
							RefCode,
							WhTicket)
						SELECT
							b.transid,
							b.refno,
							b.custid,
							b.recommend,
							b.currency,
							b.bettype,
							b.betid,
							b.betteam,
							b.hdp1,
							b.hdp2,
							b.oddstype,
							b.odds,
							b.modds,
							b.oddsspread,
							b.stake,
							b.actual_stake,
							(b.winlost - b.actual_stake) AS WinLost,
							CASE
								WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
								ELSE - (b.winlost - b.actual_stake)
							END AS LiceseeWL,
							b.comm,
							b.playercomm,
							b.status,
							b.statusID,
							b.transdate,
							b.winlostdate,
							b.liveindicator,
							b.livehomescore,
							b.liveawayscore,
							b.ip,
							b.betfrom,
							b.matchid,
							b.betcheck,
							b.transdesc,
							b.betdaqid,
							b.ExtraInfo,
							b.WalletType,
							ISNULL(b.RefCode, 0),
							2 AS WhTicket
						FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
							INNER JOIN #TempAg AS a ON b.recommend = a.CustId
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
							LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
							LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
							LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
						WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
							AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
							AND b.bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
							AND b.bettype NOT BETWEEN 801 AND 899
							AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
								OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
							AND (@SportType = 0
								OR (m.sporttype = @SportType AND s.EventType = 1)
								OR (l.sporttype = @SportType AND b.bettype = 10)
								OR (b.matchid = @SportType AND s.ProductId IN (63))
								OR (m3rd.SportType = @SportType AND s.EventType = 5))
							AND (@LeagueId = 0
								OR (m.leagueid = @LeagueId AND s.EventType = 1)
								OR (o.leagueid = @LeagueId AND b.bettype = 10))
							AND (@MatchId = 0
								OR b.matchid = @MatchId
								OR b.matchid IN (SELECT MatchId FROM @Match))
							AND 1 = CASE
										WHEN s.ProductID = 1 THEN
											CASE
												WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
												WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
												WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
												ELSE 0
											END
										ELSE 1
									END
					END
					ELSE
					BEGIN
						INSERT INTO #Data (
							TransId,
							RefNo,
							CustId,
							Recommend,
							Currency,
							BetType,
							BetId,
							BetTeam,
							Hdp1,
							Hdp2,
							OddsType,
							Odds,
							MOdds,
							OddsSpread,
							Stake,
							Actual_Stake,
							WinLost,
							LicenseeWL,
							Comm,
							PlayerComm,
							Status,
							StatusId,
							TransDate,
							WinLostDate,
							LiveIndicator,
							LiveHomeScore,
							LiveAwayScore,
							Ip,
							BetFrom,
							MatchId,
							BetCheck,
							TransDesc,
							BetdaqId,
							ExtraInfo,
							WalletType,
							RefCode,
							WhTicket)
						SELECT
							b.transid,
							b.refno,
							b.custid,
							b.recommend,
							b.currency,
							b.bettype,
							b.betid,
							b.betteam,
							b.hdp1,
							b.hdp2,
							b.oddstype,
							b.odds,
							b.modds,
							b.oddsspread,
							b.stake,
							b.actual_stake,
							(b.winlost - b.actual_stake) AS WinLost,
							CASE
								WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
								ELSE - (b.winlost - b.actual_stake)
							END AS LiceseeWL,
							b.comm,
							b.playercomm,
							b.status,
							b.statusID,
							b.transdate,
							b.winlostdate,
							b.liveindicator,
							b.livehomescore,
							b.liveawayscore,
							b.ip,
							b.betfrom,
							b.matchid,
							b.betcheck,
							b.transdesc,
							b.betdaqid,
							b.ExtraInfo,
							b.WalletType,
							ISNULL(b.RefCode, 0),
							2 AS WhTicket
						FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
							INNER JOIN #TempAg AS a ON b.recommend = a.CustId
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid
							LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
						WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
							AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
							AND b.bettype = 10
							AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
							AND (@SportType = 0 OR l.sporttype = @SportType)
							AND (@LeagueId = 0 OR o.leagueid = @LeagueId)
							AND (@MatchId = 0
								OR b.matchid = @MatchId
								OR b.matchid IN (SELECT MatchId FROM @Match))
							AND 1 = CASE
										WHEN s.ProductID = 1 THEN
											CASE
												WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
												WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
												WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
												ELSE 0
											END
										ELSE 1
									END
					END
				END
			END
		END
		ELSE
		BEGIN
			-- Bettrans range
			IF @ToDate > @MoveBetsDay
			BEGIN
				IF @FromDate <= @MoveBetsDay
					SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
				ELSE
					SET @TempFromDate = @FromDate

				IF @SportType = 0 AND @LeagueId = 0
				BEGIN
					INSERT INTO #Data (
						TransId,
						RefNo,
						CustId,
						Recommend,
						Currency,
						BetType,
						BetId,
						BetTeam,
						Hdp1,
						Hdp2,
						OddsType,
						Odds,
						MOdds,
						OddsSpread,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						Comm,
						PlayerComm,
						Status,
						StatusId,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						BetCheck,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WalletType,
						RefCode,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						b.betid,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						CASE
							WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
							ELSE - (b.winlost - b.actual_stake)
						END AS LiceseeWL,
						b.comm,
						b.playercomm,
						b.status,
						b.statusID,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.betcheck,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						b.WalletType,
						ISNULL(b.RefCode, 0),
						1 AS WhTicket
					FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_CustId)
						INNER JOIN #TempCust AS c ON b.custid = c.CustId
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
					WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND b.bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
						AND b.bettype NOT BETWEEN 801 AND 899
						AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
							OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
						AND (@MatchId = 0
							OR b.matchid = @MatchId
							OR b.matchid IN (SELECT MatchId FROM @Match))
						AND 1 = CASE
									WHEN s.ProductID = 1 THEN
										CASE
											WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
											WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
											WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
											ELSE 0
										END
									ELSE 1
								END
				END
				ELSE
				BEGIN
					IF @BetType <> 10
					BEGIN
						INSERT INTO #Data (
							TransId,
							RefNo,
							CustId,
							Recommend,
							Currency,
							BetType,
							BetId,
							BetTeam,
							Hdp1,
							Hdp2,
							OddsType,
							Odds,
							MOdds,
							OddsSpread,
							Stake,
							Actual_Stake,
							WinLost,
							LicenseeWL,
							Comm,
							PlayerComm,
							Status,
							StatusId,
							TransDate,
							WinLostDate,
							LiveIndicator,
							LiveHomeScore,
							LiveAwayScore,
							Ip,
							BetFrom,
							MatchId,
							BetCheck,
							TransDesc,
							BetdaqId,
							ExtraInfo,
							WalletType,
							RefCode,
							WhTicket)
						SELECT
							b.transid,
							b.refno,
							b.custid,
							b.recommend,
							b.currency,
							b.bettype,
							b.betid,
							b.betteam,
							b.hdp1,
							b.hdp2,
							b.oddstype,
							b.odds,
							b.modds,
							b.oddsspread,
							b.stake,
							b.actual_stake,
							(b.winlost - b.actual_stake) AS WinLost,
							CASE
								WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
								ELSE - (b.winlost - b.actual_stake)
							END AS LiceseeWL,
							b.comm,
							b.playercomm,
							b.status,
							b.statusID,
							b.transdate,
							b.winlostdate,
							b.liveindicator,
							b.livehomescore,
							b.liveawayscore,
							b.ip,
							b.betfrom,
							b.matchid,
							b.betcheck,
							b.transdesc,
							b.betdaqid,
							b.ExtraInfo,
							b.WalletType,
							ISNULL(b.RefCode, 0),
							1 AS WhTicket
						FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_CustId)
							INNER JOIN #TempCust AS c ON b.custid = c.CustId
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
							LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
							LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
							LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
						WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
							AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
							AND b.bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
							AND b.bettype NOT BETWEEN 801 AND 899
							AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
								OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
							AND (@SportType = 0
								OR (m.sporttype = @SportType AND s.EventType = 1)
								OR (l.sporttype = @SportType AND b.bettype = 10)
								OR (b.matchid = @SportType AND s.ProductId IN (63))
								OR (m3rd.SportType = @SportType AND s.EventType = 5))
							AND (@LeagueId = 0
								OR (m.leagueid = @LeagueId AND s.EventType = 1)
								OR (o.leagueid = @LeagueId AND b.bettype = 10))
							AND (@MatchId = 0
								OR b.matchid = @MatchId
								OR b.matchid IN (SELECT MatchId FROM @Match))
							AND 1 = CASE
										WHEN s.ProductID = 1 THEN
											CASE
												WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
												WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
												WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
												ELSE 0
											END
										ELSE 1
									END
					END
					ELSE
					BEGIN
						INSERT INTO #Data (
							TransId,
							RefNo,
							CustId,
							Recommend,
							Currency,
							BetType,
							BetId,
							BetTeam,
							Hdp1,
							Hdp2,
							OddsType,
							Odds,
							MOdds,
							OddsSpread,
							Stake,
							Actual_Stake,
							WinLost,
							LicenseeWL,
							Comm,
							PlayerComm,
							Status,
							StatusId,
							TransDate,
							WinLostDate,
							LiveIndicator,
							LiveHomeScore,
							LiveAwayScore,
							Ip,
							BetFrom,
							MatchId,
							BetCheck,
							TransDesc,
							BetdaqId,
							ExtraInfo,
							WalletType,
							RefCode,
							WhTicket)
						SELECT
							b.transid,
							b.refno,
							b.custid,
							b.recommend,
							b.currency,
							b.bettype,
							b.betid,
							b.betteam,
							b.hdp1,
							b.hdp2,
							b.oddstype,
							b.odds,
							b.modds,
							b.oddsspread,
							b.stake,
							b.actual_stake,
							(b.winlost - b.actual_stake) AS WinLost,
							CASE
								WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
								ELSE - (b.winlost - b.actual_stake)
							END AS LiceseeWL,
							b.comm,
							b.playercomm,
							b.status,
							b.statusID,
							b.transdate,
							b.winlostdate,
							b.liveindicator,
							b.livehomescore,
							b.liveawayscore,
							b.ip,
							b.betfrom,
							b.matchid,
							b.betcheck,
							b.transdesc,
							b.betdaqid,
							b.ExtraInfo,
							b.WalletType,
							ISNULL(b.RefCode, 0),
							1 AS WhTicket
						FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_CustId)
							INNER JOIN #TempCust AS c ON b.custid = c.CustId
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
							LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
						WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
							AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
							AND b.bettype = 10
							AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
							AND (@SportType = 0 OR l.sporttype = @SportType)
							AND (@LeagueId = 0 OR o.leagueid = @LeagueId)
							AND (@MatchId = 0
								OR b.matchid = @MatchId
								OR b.matchid IN (SELECT MatchId FROM @Match))
							AND 1 = CASE
										WHEN s.ProductID = 1 THEN
											CASE
												WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
												WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
												WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
												ELSE 0
											END
										ELSE 1
									END
					END
				END
			END

			-- Bettrans14 range
			IF @FromDate <= @MoveBetsDay
			BEGIN
				IF @ToDate > @MoveBetsDay
					SET @TempToDate = @MoveBetsDay
				ELSE
					SET @TempToDate = @ToDate

				IF @SportType = 0 AND @LeagueId = 0
				BEGIN
					INSERT INTO #Data (
						TransId,
						RefNo,
						CustId,
						Recommend,
						Currency,
						BetType,
						BetId,
						BetTeam,
						Hdp1,
						Hdp2,
						OddsType,
						Odds,
						MOdds,
						OddsSpread,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						Comm,
						PlayerComm,
						Status,
						StatusId,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						BetCheck,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WalletType,
						RefCode,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						b.betid,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						CASE
							WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
							ELSE - (b.winlost - b.actual_stake)
						END AS LiceseeWL,
						b.comm,
						b.playercomm,
						b.status,
						b.statusID,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.betcheck,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						b.WalletType,
						ISNULL(b.RefCode, 0),
						2 AS WhTicket
					FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_CustId)
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
						CROSS APPLY ( SELECT CustId FROM #TempCust ) AS t
					WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
						AND t.CustId = b.custid
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND b.bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
						AND b.bettype NOT BETWEEN 801 AND 899
						AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
							OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
						AND (@MatchId = 0
							OR b.matchid = @MatchId
							OR b.matchid IN (SELECT MatchId FROM @Match))
						AND 1 = CASE
									WHEN s.ProductID = 1 THEN
										CASE
											WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
											WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
											WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
											ELSE 0
										END
									ELSE 1
								END
				END
				ELSE
				BEGIN
					IF @BetType <> 10
					BEGIN
						INSERT INTO #Data (
							TransId,
							RefNo,
							CustId,
							Recommend,
							Currency,
							BetType,
							BetId,
							BetTeam,
							Hdp1,
							Hdp2,
							OddsType,
							Odds,
							MOdds,
							OddsSpread,
							Stake,
							Actual_Stake,
							WinLost,
							LicenseeWL,
							Comm,
							PlayerComm,
							Status,
							StatusId,
							TransDate,
							WinLostDate,
							LiveIndicator,
							LiveHomeScore,
							LiveAwayScore,
							Ip,
							BetFrom,
							MatchId,
							BetCheck,
							TransDesc,
							BetdaqId,
							ExtraInfo,
							WalletType,
							RefCode,
							WhTicket)
						SELECT
							b.transid,
							b.refno,
							b.custid,
							b.recommend,
							b.currency,
							b.bettype,
							b.betid,
							b.betteam,
							b.hdp1,
							b.hdp2,
							b.oddstype,
							b.odds,
							b.modds,
							b.oddsspread,
							b.stake,
							b.actual_stake,
							(b.winlost - b.actual_stake) AS WinLost,
							CASE
								WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
								ELSE - (b.winlost - b.actual_stake)
							END AS LiceseeWL,
							b.comm,
							b.playercomm,
							b.status,
							b.statusID,
							b.transdate,
							b.winlostdate,
							b.liveindicator,
							b.livehomescore,
							b.liveawayscore,
							b.ip,
							b.betfrom,
							b.matchid,
							b.betcheck,
							b.transdesc,
							b.betdaqid,
							b.ExtraInfo,
							b.WalletType,
							ISNULL(b.RefCode, 0),
							2 AS WhTicket
						FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_CustId)
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
							LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
							LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
							LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
							CROSS APPLY ( SELECT CustId FROM #TempCust ) AS t
						WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
							AND t.CustId = b.custid
							AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
							AND b.bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
							AND b.bettype NOT BETWEEN 801 AND 899
							AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
								OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
							AND (@SportType = 0
								OR (m.sporttype = @SportType AND s.EventType = 1)
								OR (l.sporttype = @SportType AND b.bettype = 10)
								OR (b.matchid = @SportType AND s.ProductId IN (63))
								OR (m3rd.SportType = @SportType AND s.EventType = 5))
							AND (@LeagueId = 0
								OR (m.leagueid = @LeagueId AND s.EventType = 1)
								OR (o.leagueid = @LeagueId AND b.bettype = 10))
							AND (@MatchId = 0
								OR b.matchid = @MatchId
								OR b.matchid IN (SELECT MatchId FROM @Match))
							AND 1 = CASE
										WHEN s.ProductID = 1 THEN
											CASE
												WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
												WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
												WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
												ELSE 0
											END
										ELSE 1
									END
					END
					ELSE
					BEGIN
						INSERT INTO #Data (
							TransId,
							RefNo,
							CustId,
							Recommend,
							Currency,
							BetType,
							BetId,
							BetTeam,
							Hdp1,
							Hdp2,
							OddsType,
							Odds,
							MOdds,
							OddsSpread,
							Stake,
							Actual_Stake,
							WinLost,
							LicenseeWL,
							Comm,
							PlayerComm,
							Status,
							StatusId,
							TransDate,
							WinLostDate,
							LiveIndicator,
							LiveHomeScore,
							LiveAwayScore,
							Ip,
							BetFrom,
							MatchId,
							BetCheck,
							TransDesc,
							BetdaqId,
							ExtraInfo,
							WalletType,
							RefCode,
							WhTicket)
						SELECT
							b.transid,
							b.refno,
							b.custid,
							b.recommend,
							b.currency,
							b.bettype,
							b.betid,
							b.betteam,
							b.hdp1,
							b.hdp2,
							b.oddstype,
							b.odds,
							b.modds,
							b.oddsspread,
							b.stake,
							b.actual_stake,
							(b.winlost - b.actual_stake) AS WinLost,
							CASE
								WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
								ELSE - (b.winlost - b.actual_stake)
							END AS LiceseeWL,
							b.comm,
							b.playercomm,
							b.status,
							b.statusID,
							b.transdate,
							b.winlostdate,
							b.liveindicator,
							b.livehomescore,
							b.liveawayscore,
							b.ip,
							b.betfrom,
							b.matchid,
							b.betcheck,
							b.transdesc,
							b.betdaqid,
							b.ExtraInfo,
							b.WalletType,
							ISNULL(b.RefCode, 0),
							2 AS WhTicket
						FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_CustId)
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid
							LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
							CROSS APPLY ( SELECT CustId FROM #TempCust ) AS t
						WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
							AND t.CustId = b.custid
							AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
							AND b.bettype = 10
							AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
							AND (@SportType = 0 OR l.sporttype = @SportType)
							AND (@LeagueId = 0 OR o.leagueid = @LeagueId)
							AND (@MatchId = 0
								OR b.matchid = @MatchId
								OR b.matchid IN (SELECT MatchId FROM @Match))
							AND 1 = CASE
										WHEN s.ProductID = 1 THEN
											CASE
												WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
												WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
												WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
												ELSE 0
											END
										ELSE 1
									END
					END
				END
			END
		END

		IF ISNULL(@Ip, '') <> ''
		BEGIN
			DELETE #Data
			WHERE Ip <> @Ip
		END

		IF @PlatformType <> 'All'
		BEGIN
			DELETE #Data
			WHERE BetFrom NOT IN (SELECT betfrom FROM dbo.Lrf_f_BetFromType_Sel(@PlatformType))
		END

		UPDATE b
		SET b.Product = CASE
							WHEN s.ProductId = 63 THEN 'SLT'						-- Sports Lottery
							WHEN s.ProductId = 69 THEN 'BTC'						-- Bitcoin
							WHEN s.EventType = 0 AND s.ProductId = 1 THEN 'Parlay'	-- Sportsbook Parlay
							WHEN s.EventType = 1 AND s.ProductId = 1 THEN 'SB'		-- Sportsbook
							WHEN s.EventType = 2 AND s.ProductId = 1 THEN 'Outright'
							ELSE 'Unknown'
						END
		FROM #Data AS b
			INNER JOIN #SportBettype AS s ON s.BetType = b.BetType

		IF EXISTS (SELECT 1 FROM @SabaSportType WHERE SportType = @SportType)
		BEGIN
			-- Get event info
			UPDATE b
			SET SportType = m.sporttype,
				LeagueId = m.leagueid,
				LeagueGroupId = l.LeagueGroupID
			FROM #Data AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
			WHERE b.Product = 'SB' AND b.WhTicket = 1

			UPDATE b
			SET SportType = m.sporttype,
				LeagueId = m.leagueid,
				LeagueGroupId = l.LeagueGroupID
			FROM #Data AS b
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
			WHERE b.Product = 'SB' AND b.WhTicket = 2

			UPDATE b
			SET SportType = l.sporttype,
				LeagueId = l.leagueid,
				LeagueGroupId = l.LeagueGroupID
			FROM #Data AS b
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE b.Product = 'Outright' AND b.WhTicket = 1

			UPDATE b
			SET SportType = l.sporttype,
				LeagueId = l.leagueid,
				LeagueGroupId = l.LeagueGroupID
			FROM #Data AS b
				INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE b.Product = 'Outright' AND b.WhTicket = 2

			IF @LeagueGroupIds <> ''
			BEGIN
				DELETE FROM #Data
				WHERE Product IN ('SB', 'Outright')
					AND ',' + @LeagueGroupIds + ',' NOT LIKE '%,' + CONVERT(VARCHAR(11), LeagueGroupId) + ',%'
			END
			ELSE
			BEGIN
				DELETE b
				FROM #Data AS b
				WHERE Product IN ('SB', 'Outright')
					AND EXISTS (SELECT 1 FROM @SabaSportType
								WHERE SportType = @SportType
									AND ',' + LeagueGroupIdList + ',' LIKE '%,' + CONVERT(VARCHAR(11), b.LeagueGroupId) + ',%')
			END
		END

		IF @Username IS NULL OR @Username = ''
		BEGIN
			INSERT INTO #TempCust (CustId, CustomerClass)
			SELECT DISTINCT
				c.custid,
				ci.CustomerClass
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = c.custid
			WHERE c.roleid = 1
				AND (@OddsGroup = 'All'
					OR ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%')
				AND EXISTS (SELECT 1 FROM #Data WHERE CustId = c.CustId)

			IF @CustomerClass <> 'All'
			BEGIN
				DELETE #TempCust
				WHERE 1 <> CASE
								WHEN ',' + @CustomerClass + ',' LIKE '%,0,%' AND CustomerClass IS NULL THEN 1
								WHEN ',' + @CustomerClass + ',' LIKE '%,0,%'
									AND ',' + @FullCustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
								WHEN ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
								ELSE 0
							END
			END
		END

		IF @Username IS NULL OR @Username = '' OR @NumOfMem <= 5000
		BEGIN
			DELETE b
			FROM #Data AS b
			WHERE b.Product = 'Unknown'
				OR NOT EXISTS (SELECT 1 FROM #TempCust WHERE CustId = b.CustId)
				OR NOT EXISTS (SELECT 1 FROM #TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
				OR (b.Product NOT IN ('SB', 'Parlay')
					AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), StatusId) + ',%')
				OR (b.Product = 'Parlay'
					AND b.Status IN ('Draw', 'Won', 'Lose')
					AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), StatusId) + ',%')
				OR (',' + @OriginalStatusIdList + ',' NOT LIKE '%,99,%'
					AND b.Status = 'Void'
					AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@ab)[1]','TINYINT'), 0) = 1)
				OR (',' + @OriginalStatusIdList + ',' NOT LIKE '%,102,%'
					AND b.Status = 'Void'
					AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@ab)[1]','TINYINT'), 0) = 0)
		END
		ELSE
		BEGIN
			DELETE b
			FROM #Data AS b
			WHERE b.Product = 'Unknown'
				OR NOT EXISTS (SELECT 1 FROM #TempCust WHERE CustId = b.CustId)
				OR NOT EXISTS (SELECT 1 FROM #TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
				OR (b.Product NOT IN ('SB', 'Parlay')
					AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), StatusId) + ',%')
				OR (b.Product = 'Parlay'
					AND b.Status IN ('Draw', 'Won', 'Lose')
					AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), StatusId) + ',%')
				OR (',' + @OriginalStatusIdList + ',' NOT LIKE '%,99,%'
					AND b.Status = 'Void'
					AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@ab)[1]','TINYINT'), 0) = 1)
				OR (',' + @OriginalStatusIdList + ',' NOT LIKE '%,102,%'
					AND b.Status = 'Void'
					AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@ab)[1]','TINYINT'), 0) = 0)
		END

		IF EXISTS (SELECT 1 FROM #Data WHERE Product = 'SB' AND Status IN ('Draw', 'Won', 'Lose'))
		BEGIN
			UPDATE b
			SET b.SettlementStatus = m.SettlementStatus
			FROM #Data AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.matchid
			WHERE b.Product = 'SB' AND b.Status IN ('Draw', 'Won', 'Lose')

			IF ',' + @OriginalStatusIdList + ',' NOT LIKE '%,111,%'		-- Not include Draw, Won, Lose
				OR ',' + @OriginalStatusIdList + ',' NOT LIKE '%,112,%'
				OR ',' + @OriginalStatusIdList + ',' NOT LIKE '%,113,%'
			BEGIN
				DELETE FROM #Data
				WHERE Product = 'SB'
					AND (ISNULL(SettlementStatus, 0) & 1 = 0		-- isPending flag (bit 1) = 0
						OR (Stake = 0								-- Cash Out All
							AND BetdaqId = 0
							AND ExtraInfo LIKE '%p25%'))
					AND ((Status = 'Draw' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,111,%')
						OR (Status = 'Won' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,112,%')
						OR (Status = 'Lose' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,113,%'))
			END

			IF ',' + @OriginalStatusIdList + ',' NOT LIKE '%,2,%'		-- Not include Delay Payout
			BEGIN
				DELETE #Data
				WHERE Product = 'SB'
					AND ISNULL(SettlementStatus, 0) & 1 <> 0		-- isPending flag (bit 1) = 1
					AND Status IN ('Draw', 'Won', 'Lose')
					AND (Stake <> 0						-- Not Cash Out All
						OR BetdaqId <> 0
						OR ExtraInfo NOT LIKE '%p25%')
			END
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			-- Get data for summary ticket of multiple Bonus/Cash sub tickets
			IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
			BEGIN
				DECLARE @RefCodeTmp TABLE (
					RefCode			BIGINT,
					TransId			BIGINT,
					Stake			MONEY,
					Actual_Stake	MONEY,
					WinLost			MONEY,
					LicenseeWL		MONEY,
					Comm			MONEY,
					PlayerComm		MONEY
				)

				-- Prepare temp table
				INSERT INTO @RefCodeTmp
				SELECT
					RefCode,
					MIN(TransId) AS TransId,
					SUM(Stake) AS Stake,
					SUM(Actual_Stake) AS Actual_Stake,
					SUM(WinLost) AS WinLost,
					SUM(LicenseeWL) AS LicenseeWL,
					SUM(Comm) AS Comm,
					SUM(PlayerComm) AS PlayerComm
				FROM #Data
				WHERE RefCode <> 0
				GROUP BY RefCode
				HAVING COUNT(*) > 1

				IF EXISTS (SELECT 1 FROM @RefCodeTmp)
				BEGIN
					-- Update data for summmary ticket
					UPDATE b
					SET
						b.Stake = r.Stake,
						b.Actual_Stake = r.Actual_Stake,
						b.WinLost = r.WinLost,
						b.LicenseeWL = r.LicenseeWL,
						b.Comm = r.Comm,
						b.PlayerComm = r.PlayerComm,
						b.WalletType = 0
					FROM #Data AS b
						INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

					-- Delete 2nd Bonus/Cash tickets
					DELETE #Data
					WHERE WalletType <> 0
						AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
				END
			END

			-- Display detail link for ticket from Bonus Wallet only
			UPDATE #Data
			SET RefCode = TransId
			WHERE WalletType = 1 AND RefCode = 0

			-- Don't display Cash text for ticket from Cash Wallet only
			UPDATE #Data
			SET WalletType = 0
			WHERE WalletType = 2 AND RefCode = 0

			DECLARE @ExFromDate SMALLDATETIME,
				@ExToDate SMALLDATETIME

			SELECT
				@ExFromDate = MIN(WinLostDate),
				@ExToDate = MAX(WinLostDate)
			FROM #Data

			-- Get exchange rate
			INSERT INTO #ExchangeRate
			SELECT
				e.ExchangeId,
				e.FromDate,
				e.ToDate,
				e.Rate
			FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
			WHERE EXISTS (SELECT 1 FROM #Data
						WHERE Currency = e.ExchangeId
							AND WinLostDate BETWEEN e.FromDate AND e.ToDate)

			-- Return data
			SELECT
				@TotalRows		= COUNT(b.TransId),
				@SumStake		= SUM(b.Stake		* ISNULL(e.Rate, 1)),
				@SumWinlost		= SUM(b.WinLost		* ISNULL(e.Rate, 1)),
				@SumLicenseeWL	= SUM(b.LicenseeWL	* ISNULL(e.Rate, 1)),
				@SumComm		= SUM(b.Comm		* ISNULL(e.Rate, 1)),
				@SumPlayerComm	= SUM(b.PlayerComm	* ISNULL(e.Rate, 1))
			FROM #Data AS b
				LEFT JOIN #ExchangeRate AS e
					ON e.ExchangeId = b.Currency
					AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

			IF @ConvertToBaseCur = 0
			BEGIN
				DELETE FROM #ExchangeRate
			END

			-- Get sort text
			IF @ConvertToBaseCur = 1
				AND (@Sort LIKE '%Stake%' OR @Sort LIKE '%WinLost%' OR @Sort LIKE '%LicenseeWL%')
			BEGIN
				DECLARE @CharIndex TINYINT

				SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

				SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(e.Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
			END
		END

		IF @PageSize < @TotalRows
		BEGIN
			-- Paging
			DECLARE @RowStart INT,
				@RowEnd INT

			SELECT @PageIndex = @PageIndex - 1,
				@RowStart = @PageSize * @PageIndex + 1,
				@RowEnd = @RowStart + @PageSize - 1

			DECLARE @Sql NVARCHAR(MAX)

			SET @Sql = 
				N'SELECT a.*
				FROM
					(
						SELECT
							ROW_NUMBER() OVER (ORDER BY ' + @Sort + N') AS RowNum,
							d.*
						FROM #Data AS d' +
						CASE
							WHEN @Sort LIKE '%e.Rate%' THEN N'
							LEFT JOIN #ExchangeRate AS e
								ON e.ExchangeId = d.Currency
									AND d.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth'
							ELSE N' '
						END + N'
					) AS a
				WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
				ORDER BY a.RowNum'

			INSERT INTO #PagingData
			EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

			-- bettrans
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE WhTicket = 1)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
					SportType = CASE
									WHEN b.Product = 'SLT' THEN b.MatchId
									WHEN b.Product = 'SB' THEN m.sporttype
									WHEN b.Product = 'BTC' THEN m3rd.SportType
									WHEN b.Product = 'Outright' THEN l.sporttype
									ELSE 0
								END,
					BetId = ISNULL(b.BetId, 0),
					BetTeam = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'BTC') THEN b.BetTeam
								ELSE ''
							END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'BTC') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'Parlay') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
								WHEN b.Product IN ('SB', 'Outright') THEN b.OddsType
								ELSE 0
							END,
					Odds = CASE
							WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'SLT', 'BTC') THEN b.Odds
							ELSE 0
						END,
					MOdds = CASE
							WHEN b.Product IN ('SB', 'Parlay', 'Outright') THEN b.MOdds
							ELSE 0
						END,
					OddsSpread = CASE
							WHEN b.Product IN ('SB') THEN b.OddsSpread
							ELSE 0
						END,
					SettlementStatus = CASE
										WHEN b.Product = 'SB' THEN ISNULL(m.SettlementStatus, 0)
										ELSE 0
									END,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB') THEN b.LiveIndicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'Parlay') THEN b.LiveHomeScore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB') THEN b.LiveAwayScore
										ELSE 0
									END,
					LeagueId = CASE
								WHEN b.Product IN ('SB') THEN m.leagueid
								WHEN b.Product = 'Outright' THEN o.leagueid
								ELSE 0
							END,
					LeagueGroupId = CASE
									WHEN b.Product IN ('SB') THEN le.LeagueGroupID
									ELSE 0
								END,
					MatchId = CASE
								WHEN b.Product IN ('SB', 'BTC') THEN b.matchid
								ELSE 0
							END,
					MatchCode = CASE
									WHEN b.Product IN ('SB') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB') THEN m.GlobalShowTime
									WHEN b.Product IN ('BTC') THEN m3rd.EndTime
									ELSE b.WinLostDate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('SB') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.showtime, '')
									ELSE ''
								END,
					BetCheck = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'SLT') THEN ISNULL(b.BetCheck, '')
								ELSE ''
							END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'SLT') THEN ISNULL(b.TransDesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.BetdaqId, -1)
									ELSE -1
								END,
					ExtraInfo = CASE
									WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'SLT', 'BTC') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					OriginalStake = CASE
										WHEN b.Product = 'SB' AND b.ExtraInfo LIKE '%p25%' THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
										ELSE 0
									END,
					OriginalBetType = CASE
										WHEN b.Product = 'SB' AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('SLT') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #PagingData AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product = 'SB' AND b.matchid = m.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON b.Product = 'BTC' AND m3rd.Match3rdId = b.matchid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product = 'Outright' AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product = 'Outright' AND o.leagueid = l.leagueid
				WHERE b.WhTicket = 1
			END

			-- bettrans14
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE WhTicket = 2)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
					SportType = CASE
									WHEN b.Product = 'SLT' THEN b.MatchId
									WHEN b.Product = 'SB' THEN m.sporttype
									WHEN b.Product = 'BTC' THEN m3rd.SportType
									WHEN b.Product = 'Outright' THEN l.sporttype
									ELSE 0
								END,
					BetId = ISNULL(b.BetId, 0),
					BetTeam = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'BTC') THEN b.BetTeam
								ELSE ''
							END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'BTC') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'Parlay') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
								WHEN b.Product IN ('SB', 'Outright') THEN b.OddsType
								ELSE 0
							END,
					Odds = CASE
							WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'SLT', 'BTC') THEN b.Odds
							ELSE 0
						END,
					MOdds = CASE
							WHEN b.Product IN ('SB', 'Parlay', 'Outright') THEN b.MOdds
							ELSE 0
						END,
					OddsSpread = CASE
							WHEN b.Product IN ('SB') THEN b.OddsSpread
							ELSE 0
						END,
					SettlementStatus = 0,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB') THEN b.LiveIndicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'Parlay') THEN b.LiveHomeScore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB') THEN b.LiveAwayScore
										ELSE 0
									END,
					LeagueId = CASE
								WHEN b.Product IN ('SB') THEN m.leagueid
								WHEN b.Product = 'Outright' THEN o.leagueid
								ELSE 0
							END,
					LeagueGroupId = CASE
									WHEN b.Product IN ('SB') THEN le.LeagueGroupID
									ELSE 0
								END,
					MatchId = CASE
								WHEN b.Product IN ('SB', 'BTC') THEN b.matchid
								ELSE 0
							END,
					MatchCode = CASE
									WHEN b.Product IN ('SB') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB') THEN m.GlobalShowTime
									WHEN b.Product IN ('BTC') THEN m3rd.EndTime
									ELSE b.WinLostDate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('SB') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.showtime, '')
									ELSE ''
								END,
					BetCheck = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'SLT') THEN ISNULL(b.BetCheck, '')
								ELSE ''
							END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'SLT') THEN ISNULL(b.TransDesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.BetdaqId, -1)
									ELSE -1
								END,
					ExtraInfo = CASE
									WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'SLT', 'BTC') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					OriginalStake = CASE
										WHEN b.Product = 'SB' AND b.ExtraInfo LIKE '%p25%' THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
										ELSE 0
									END,
					OriginalBetType = CASE
										WHEN b.Product = 'SB' AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('SLT') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #PagingData AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Product = 'SB' AND b.matchid = m.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON b.Product = 'BTC' AND m3rd.Match3rdId = b.matchid
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product = 'Outright' AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product = 'Outright' AND o.leagueid = l.leagueid
				WHERE b.WhTicket = 2
			END

			-- Return data
			SELECT
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
				a.TransId,
				a.RefNo,
				a.BetId,
				a.CustId,
				a.TransDate,
				a.WinLostDate,
				a.SportType,
				a.BetType,
				a.BetTeam,
				a.Hdp1,
				a.Hdp2,
				a.Odds,
				a.MOdds,
				a.OddsType,
				a.OddsSpread,
				a.Status,
				a.SettlementStatus,
				a.LiveIndicator,
				a.LiveHomeScore,
				a.LiveAwayScore,
				a.Race,
				a.LeagueId,
				a.LeagueGroupId,
				a.MatchId,
				a.MatchCode,
				a.EventDate,
				a.HomeId,
				a.AwayId,
				a.IsNeutral,
				a.BetStatus,
				a.ShowTime,
				a.Currency,
				a.Stake * ISNULL(e.Rate, 1) AS Stake,
				a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
				a.WinLost * ISNULL(e.Rate, 1) AS WinLost,
				a.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
				a.Comm * ISNULL(e.Rate, 1) AS Comm,
				a.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
				a.Ip,
				a.BetFrom,
				a.BetCheck,
				a.TransDesc,
				a.BetdaqId,
				a.ExtraInfo,
				a.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
				a.OriginalBetType,
				a.WalletType,
				a.RefCode,
				a.SiteId,
				ci.CustomerClass
			FROM
				#PagingData AS a
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = a.CustId
				INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = a.CustId
				LEFT JOIN #ExchangeRate AS e
					ON e.ExchangeId = a.Currency
						AND a.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			ORDER BY a.RowNum
		END
		ELSE
		BEGIN
			-- bettrans
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE WhTicket = 1)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
					SportType = CASE
									WHEN b.Product = 'SLT' THEN b.MatchId
									WHEN b.Product = 'SB' THEN m.sporttype
									WHEN b.Product = 'BTC' THEN m3rd.SportType
									WHEN b.Product = 'Outright' THEN l.sporttype
									ELSE 0
								END,
					BetId = ISNULL(b.BetId, 0),
					BetTeam = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'BTC') THEN b.BetTeam
								ELSE ''
							END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'BTC') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'Parlay') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
								WHEN b.Product IN ('SB', 'Outright') THEN b.OddsType
								ELSE 0
							END,
					Odds = CASE
							WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'SLT', 'BTC') THEN b.Odds
							ELSE 0
						END,
					MOdds = CASE
							WHEN b.Product IN ('SB', 'Parlay', 'Outright') THEN b.MOdds
							ELSE 0
						END,
					OddsSpread = CASE
							WHEN b.Product IN ('SB') THEN b.OddsSpread
							ELSE 0
						END,
					SettlementStatus = CASE
										WHEN b.Product = 'SB' THEN ISNULL(m.SettlementStatus, 0)
										ELSE 0
									END,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB') THEN b.LiveIndicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'Parlay') THEN b.LiveHomeScore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB') THEN b.LiveAwayScore
										ELSE 0
									END,
					LeagueId = CASE
								WHEN b.Product IN ('SB') THEN m.leagueid
								WHEN b.Product = 'Outright' THEN o.leagueid
								ELSE 0
							END,
					LeagueGroupId = CASE
									WHEN b.Product IN ('SB') THEN le.LeagueGroupID
									ELSE 0
								END,
					MatchId = CASE
								WHEN b.Product IN ('SB', 'BTC') THEN b.matchid
								ELSE 0
							END,
					MatchCode = CASE
									WHEN b.Product IN ('SB') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB') THEN m.GlobalShowTime
									WHEN b.Product IN ('BTC') THEN m3rd.EndTime
									ELSE b.WinLostDate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('SB') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.showtime, '')
									ELSE ''
								END,
					BetCheck = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'SLT') THEN ISNULL(b.BetCheck, '')
								ELSE ''
							END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'SLT') THEN ISNULL(b.TransDesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.BetdaqId, -1)
									ELSE -1
								END,
					ExtraInfo = CASE
									WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'SLT', 'BTC') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					OriginalStake = CASE
										WHEN b.Product = 'SB' AND b.ExtraInfo LIKE '%p25%' THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
										ELSE 0
									END,
					OriginalBetType = CASE
										WHEN b.Product = 'SB' AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('SLT') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #Data AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product = 'SB' AND b.matchid = m.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON b.Product = 'BTC' AND m3rd.Match3rdId = b.matchid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product = 'Outright' AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product = 'Outright' AND o.leagueid = l.leagueid
				WHERE b.WhTicket = 1
			END

			-- bettrans14
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE WhTicket = 2)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
					SportType = CASE
									WHEN b.Product = 'SLT' THEN b.MatchId
									WHEN b.Product = 'SB' THEN m.sporttype
									WHEN b.Product = 'BTC' THEN m3rd.SportType
									WHEN b.Product = 'Outright' THEN l.sporttype
									ELSE 0
								END,
					BetId = ISNULL(b.BetId, 0),
					BetTeam = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'BTC') THEN b.BetTeam
								ELSE ''
							END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'BTC') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'Parlay') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
								WHEN b.Product IN ('SB', 'Outright') THEN b.OddsType
								ELSE 0
							END,
					Odds = CASE
							WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'SLT', 'BTC') THEN b.Odds
							ELSE 0
						END,
					MOdds = CASE
							WHEN b.Product IN ('SB', 'Parlay', 'Outright') THEN b.MOdds
							ELSE 0
						END,
					OddsSpread = CASE
							WHEN b.Product IN ('SB') THEN b.OddsSpread
							ELSE 0
						END,
					SettlementStatus = 0,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB') THEN b.LiveIndicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'Parlay') THEN b.LiveHomeScore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB') THEN b.LiveAwayScore
										ELSE 0
									END,
					LeagueId = CASE
								WHEN b.Product IN ('SB') THEN m.leagueid
								WHEN b.Product = 'Outright' THEN o.leagueid
								ELSE 0
							END,
					LeagueGroupId = CASE
									WHEN b.Product IN ('SB') THEN le.LeagueGroupID
									ELSE 0
								END,
					MatchId = CASE
								WHEN b.Product IN ('SB', 'BTC') THEN b.matchid
								ELSE 0
							END,
					MatchCode = CASE
									WHEN b.Product IN ('SB') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB') THEN m.GlobalShowTime
									WHEN b.Product IN ('BTC') THEN m3rd.EndTime
									ELSE b.WinLostDate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('SB') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.showtime, '')
									ELSE ''
								END,
					BetCheck = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'SLT') THEN ISNULL(b.BetCheck, '')
								ELSE ''
							END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'SLT') THEN ISNULL(b.TransDesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.BetdaqId, -1)
									ELSE -1
								END,
					ExtraInfo = CASE
									WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'SLT', 'BTC') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					OriginalStake = CASE
										WHEN b.Product = 'SB' AND b.ExtraInfo LIKE '%p25%' THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
										ELSE 0
									END,
					OriginalBetType = CASE
										WHEN b.Product = 'SB' AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('SLT') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #Data AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Product = 'SB' AND b.matchid = m.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON b.Product = 'BTC' AND m3rd.Match3rdId = b.matchid
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product = 'Outright' AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product = 'Outright' AND o.leagueid = l.leagueid
				WHERE b.WhTicket = 2
			END
			
			CREATE TABLE #Customer (
				CustId			INT,
				Username		VARCHAR(30),
				NickName		VARCHAR(50),
				CustomerClass	SMALLINT)

			INSERT INTO #Customer (
				CustId,
				Username,
				NickName,
				CustomerClass)
			SELECT
				c.custid,
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
				ci.CustomerClass
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = c.custid
			WHERE c.custid IN (SELECT DISTINCT CustId FROM #Data)

			SET @Sql = 
				N'SELECT
					c.Username,
					c.NickName,
					a.TransId,
					a.RefNo,
					a.BetId,
					a.CustId,
					a.TransDate,
					a.WinLostDate,
					a.SportType,
					a.BetType,
					a.BetTeam,
					a.Hdp1,
					a.Hdp2,
					a.Odds,
					a.MOdds,
					a.OddsType,
					a.OddsSpread,
					a.Status,
					a.SettlementStatus,
					a.LiveIndicator,
					a.LiveHomeScore,
					a.LiveAwayScore,
					a.Race,
					a.LeagueId,
					a.LeagueGroupId,
					a.MatchId,
					a.MatchCode,
					a.EventDate,
					a.HomeId,
					a.AwayId,
					a.IsNeutral,
					a.BetStatus,
					a.ShowTime,
					a.Currency,
					a.Stake * ISNULL(e.Rate, 1) AS Stake,
					a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
					a.WinLost * ISNULL(e.Rate, 1) AS WinLost,
					a.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
					a.Comm * ISNULL(e.Rate, 1) AS Comm,
					a.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
					a.Ip,
					a.BetFrom,
					a.BetCheck,
					a.TransDesc,
					a.BetdaqId,
					a.ExtraInfo,
					a.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
					a.OriginalBetType,
					a.WalletType,
					a.RefCode,
					a.SiteId,
					c.CustomerClass
				FROM
					#Data AS a
					INNER JOIN #Customer AS c ON c.custid = a.CustId
					LEFT JOIN #ExchangeRate AS e
						ON e.ExchangeId = a.Currency
							AND a.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
				ORDER BY ' + @Sort

			EXEC sp_executesql @Sql

			DROP TABLE #Customer
		END
	END
	ELSE
	BEGIN
		SELECT * FROM #Data
	END

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #PagingData
	DROP TABLE #TempAg
	DROP TABLE #TempCust
	DROP TABLE #Data
	DROP TABLE #ExchangeRate
	DROP TABLE #SportBettype
END
GO
