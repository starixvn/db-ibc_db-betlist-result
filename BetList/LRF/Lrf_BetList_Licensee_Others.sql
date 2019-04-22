/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Licensee_Others]
	@AgentList			VARCHAR(MAX),
	@Username			VARCHAR(50)		= '',
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@SportType			TINYINT			= 0,
	@BetType			SMALLINT		= 0,
	@BaseCurrency		VARCHAR(10),
	@ConvertToBaseCur	BIT				= 0,	-- Convert to base currency or not
	@StatusIdList		VARCHAR(50)		= '',
	@LiveIndicator		VARCHAR(10)		= '0,1,2',
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@Sort				NVARCHAR(50)	= N'Transid ASC',
	@Product			VARCHAR(10)		= '',
	@TotalRows			INT				= 0 OUTPUT,
	@SumStake			MONEY			= 0 OUTPUT,
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Multiple Customer Bet List - Other products except SB and BA
	DB: DBEXT.bodb02
	Parameter's Explanation:
		- @StatusIdList:
			- 101: Reject
			- 102: Void (not include Abnormal Bets)
			- 103: Refund
			- 111: Draw
			- 112: Won
			- 113: Lose
			- 99: Abnormal Bets
		- @LiveIndicator:
			- 0 : Non-live
			- 1 : Live
			- 2 : Mix Non Live & Live

	Revisions:
		- 20190214@Kos: Betting Ticket Center phase 3b [Redmine: #108221]
		- 20190314@Kos: Change param @LiveIndicator from TINYINT to VARCHAR(10) [Redmine: #108717]
					- Add new param @Username, @ConvertToBaseCur
		- 20190422@Kos: Enhance performance for searching too many members [Redmine: #112313]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	DECLARE @HasError BIT = 0

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
		SET @HasError = 1
	END CATCH

	CREATE TABLE #Data (
		TransId			BIGINT,
		RefNo			BIGINT,
		CustId			INT,
		Recommend		INT,
		Currency		SMALLINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetId			BIGINT,
		BetTeam			NVARCHAR(20),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsId			INT,
		OddsType		TINYINT,
		Odds			MONEY,
		MOdds			MONEY,
		OddsSpread		MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR(1),
		LeagueId		INT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		Placing			NVARCHAR(20),
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		ComStatus		NVARCHAR(20),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		OriginalBetType	SMALLINT,
		Product			VARCHAR(30),
		WhTicket		TINYINT
	)

	CREATE TABLE #PagingData (
		RowNum			INT,
		TransId			BIGINT,
		RefNo			BIGINT,
		CustId			INT,
		Recommend		INT,
		Currency		SMALLINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetId			BIGINT,
		BetTeam			NVARCHAR(20),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsId			INT,
		OddsType		TINYINT,
		Odds			MONEY,
		MOdds			MONEY,
		OddsSpread		MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR(1),
		LeagueId		INT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		Placing			NVARCHAR(20),
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		ComStatus		NVARCHAR(20),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		OriginalBetType	SMALLINT,
		Product			VARCHAR(30),
		WhTicket		TINYINT
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

	IF @HasError = 0 AND @StatusIdList <> '99'		-- Abnormal Bet only
	BEGIN
		-- Get SportBettypeMatrix
		DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		IF @Product <> ''
		BEGIN
			INSERT INTO @SportBettype
			SELECT ProductID, BetType, EventType, SubProduct
			FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @Product, @IsTest)
			WHERE (@BetType = 0 OR BetType = @BetType)
				AND BetType <> 914
		END

		DECLARE @TempToDate	SMALLDATETIME,
			@TempFromDate	SMALLDATETIME

		-- Bettrans range
		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay
				SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
			ELSE
				SET @TempFromDate = @FromDate

			IF @SportType = 0
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
					OddsId,
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
					TransDate,
					WinLostDate,
					LiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					Ip,
					BetFrom,
					MatchId,
					BetCheck,
					ComStatus,
					TransDesc,
					BetdaqId,
					Product,
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
					b.oddsid,
					b.oddstype,
					b.odds,
					b.modds,
					b.oddsspread,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					- (b.winlost - b.actual_stake) AS LiceseeWL,
					b.comm,
					b.playercomm,
					b.status,
					b.transdate,
					b.winlostdate,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					b.betfrom,
					b.matchid,
					b.betcheck,
					b.comstatus,
					b.transdesc,
					b.betdaqid,
					CASE
						WHEN s.EventType = 0 AND s.ProductID = 8 THEN 'Keno'
						WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
						WHEN s.EventType = 0 AND s.ProductID = 28 THEN 'Lottery'
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 25 THEN 'CO'			-- Cash Out
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
						WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
						ELSE 'Unknown'
					END AS Product,
					1 AS WhTicket
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
					INNER JOIN @TempAg AS a ON b.recommend = a.CustId
					INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ((b.bettype = 2799 AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
						OR (b.bettype <> 2799 AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
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
					OddsId,
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
					TransDate,
					WinLostDate,
					LiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					Ip,
					BetFrom,
					MatchId,
					BetCheck,
					ComStatus,
					TransDesc,
					BetdaqId,
					Product,
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
					b.oddsid,
					b.oddstype,
					b.odds,
					b.modds,
					b.oddsspread,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					- (b.winlost - b.actual_stake) AS LiceseeWL,
					b.comm,
					b.playercomm,
					b.status,
					b.transdate,
					b.winlostdate,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					b.betfrom,
					b.matchid,
					b.betcheck,
					b.comstatus,
					b.transdesc,
					b.betdaqid,
					CASE
						WHEN s.EventType = 0 AND s.ProductID = 8 THEN 'Keno'
						WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
						WHEN s.EventType = 0 AND s.ProductID = 28 THEN 'Lottery'
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 25 THEN 'CO'			-- Cash Out
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
						WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
						ELSE 'Unknown'
					END AS Product,
					1 AS WhTicket
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
					INNER JOIN @TempAg AS a ON b.recommend = a.CustId
					INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1 AND s.ProductID IN (3, 5, 25, 27)
					LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.oddsid = vo.Orid AND s.EventType = 3 AND s.ProductID = 5
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = vo.EventID AND s.EventType = 3 AND s.ProductID = 5
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
						OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
					AND ((s.EventType = 1 AND s.ProductID IN (3, 5, 25, 27) AND m.sporttype = @SportType)
						OR (s.EventType = 3 AND s.ProductID = 5 AND vr.sporttype = @SportType)
						OR (s.ProductID IN (8, 28) AND b.matchid = @SportType))
			END

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 911 AND WhTicket = 1)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM #Data AS b
					INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911 AND b.WhTicket = 1
			END

			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 912 AND WhTicket = 1)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid,
					b.Stake = cob.stake,
					b.Comm = ISNULL(cb.awinlost, 0)
				FROM #Data AS b
					INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN dbo.bettrans AS cb
						ON cb.RefNo = b.RefNo
						AND cb.BetType = 913
						AND cb.custid = b.CustId
						AND cb.winlostdate = b.WinLostDate
				WHERE b.BetType = 912 AND b.WhTicket = 1
			END
		END

		-- Bettrans14 range
		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @ToDate > @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET @TempToDate = @ToDate

			IF @SportType = 0
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
					OddsId,
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
					TransDate,
					WinLostDate,
					LiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					Ip,
					BetFrom,
					MatchId,
					BetCheck,
					ComStatus,
					TransDesc,
					BetdaqId,
					Product,
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
					b.oddsid,
					b.oddstype,
					b.odds,
					b.modds,
					b.oddsspread,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					- (b.winlost - b.actual_stake) AS LiceseeWL,
					b.comm,
					b.playercomm,
					b.status,
					b.transdate,
					b.winlostdate,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					b.betfrom,
					b.matchid,
					b.betcheck,
					b.comstatus,
					b.transdesc,
					b.betdaqid,
					CASE
						WHEN s.EventType = 0 AND s.ProductID = 8 THEN 'Keno'
						WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
						WHEN s.EventType = 0 AND s.ProductID = 28 THEN 'Lottery'
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 25 THEN 'CO'			-- Cash Out
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
						WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
						ELSE 'Unknown'
					END AS Product,
					2 AS WhTicket
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
					INNER JOIN @TempAg AS a ON b.recommend = a.CustId
					INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
				WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ((b.bettype = 2799 AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
						OR (b.bettype <> 2799 AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
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
					OddsId,
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
					TransDate,
					WinLostDate,
					LiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					Ip,
					BetFrom,
					MatchId,
					BetCheck,
					ComStatus,
					TransDesc,
					BetdaqId,
					Product,
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
					b.oddsid,
					b.oddstype,
					b.odds,
					b.modds,
					b.oddsspread,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					- (b.winlost - b.actual_stake) AS LiceseeWL,
					b.comm,
					b.playercomm,
					b.status,
					b.transdate,
					b.winlostdate,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					b.betfrom,
					b.matchid,
					b.betcheck,
					b.comstatus,
					b.transdesc,
					b.betdaqid,
					CASE
						WHEN s.EventType = 0 AND s.ProductID = 8 THEN 'Keno'
						WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
						WHEN s.EventType = 0 AND s.ProductID = 28 THEN 'Lottery'
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 25 THEN 'CO'			-- Cash Out
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
						WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
						ELSE 'Unknown'
					END AS Product,
					2 AS WhTicket
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
					INNER JOIN @TempAg AS a ON b.recommend = a.CustId
					INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1 AND s.ProductID IN (3, 5, 25, 27)
					LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.oddsid = vo.Orid AND s.EventType = 3 AND s.ProductID = 5
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = vo.EventID AND s.EventType = 3 AND s.ProductID = 5
				WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
						OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
					AND ((s.EventType = 1 AND s.ProductID IN (3, 5, 25, 27) AND m.sporttype = @SportType)
						OR (s.EventType = 3 AND s.ProductID = 5 AND vr.sporttype = @SportType)
						OR (s.ProductID IN (8, 28) AND b.matchid = @SportType))
			END

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 911 AND WhTicket = 2)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM #Data AS b
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911 AND b.WhTicket = 2
			END

			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 912 AND WhTicket = 2)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid,
					b.Stake = cob.stake,
					b.Comm = ISNULL(cb.awinlost, 0)
				FROM #Data AS b
					INNER JOIN dbo.bettrans14 AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN dbo.bettrans14 AS cb
						ON cb.RefNo = b.RefNo
						AND cb.BetType = 913
						AND cb.custid = b.CustId
						AND cb.winlostdate = b.WinLostDate
				WHERE b.BetType = 912 AND b.WhTicket = 2
			END
		END

		IF @Username IS NULL OR @Username = ''
		BEGIN
			DELETE b
			FROM #Data AS b
			WHERE b.Product = 'Unknown'
				OR NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
				OR b.BetType = 913
		END
		ELSE
		BEGIN
			DECLARE @TempCust TABLE (CustId INT)

			INSERT INTO @TempCust
			SELECT c.custid
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN @TempAg AS a ON c.recommend = a.CustId
			WHERE c.roleid = 1
				AND (c.username LIKE + '%' + @Username + '%'
					OR c.username2 LIKE + '%$%' + @Username + '%')

			DELETE b
			FROM #Data AS b
			WHERE b.Product = 'Unknown'
				OR NOT EXISTS (SELECT 1 FROM @TempCust WHERE CustId = b.CustId)
				OR NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
				OR b.BetType = 913
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
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
					ELSE 1
				END AS Rate
			FROM dbo.Lrf_f_GetSubExchangeDaily(@ExFromDate, @ExToDate) AS e
			WHERE EXISTS (SELECT 1 FROM #Data
						WHERE Currency = e.ExchangeId
							AND WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)

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
					SportType = CASE
									WHEN b.Product IN ('Keno', 'Lottery') THEN b.MatchId
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'ParlayVS2') THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'ParlayVS2') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('CO', 'VS', 'VS2', 'VR', 'ParlayVS2') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR') THEN b.OddsType
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'Keno', 'ParlayVS2', 'Lottery') THEN b.Odds
								ELSE 0
							END,
					MOdds = CASE 
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'ParlayVS2')  THEN b.modds 
								ELSE 0
							END,
					LiveIndicator = CASE
										WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'ParlayVS2') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.matchid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.matchcode
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE ''
							END,
					HomeId = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.homeid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					Placing = CASE
									WHEN b.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE ''
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('ParlayVS2') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
									WHEN b.Product IN ('CO') AND b.bettype IN (216, 217) THEN ISNULL(b.betcheck, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('CO', 'VS2', 'Keno', 'Lottery') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('CO') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					OriginalBetType = CASE
										WHEN b.Product IN ('CO') THEN b.OriginalBetType
										ELSE 0
									END
				FROM #PagingData AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('CO', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
					LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				WHERE b.WhTicket = 1
			END

			-- bettrans14
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE WhTicket = 2)
			BEGIN
				UPDATE b
				SET
					SportType = CASE
									WHEN b.Product IN ('Keno', 'Lottery') THEN b.MatchId
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'ParlayVS2') THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'ParlayVS2') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('CO', 'VS', 'VS2', 'VR', 'ParlayVS2') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR') THEN b.OddsType
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'Keno', 'ParlayVS2', 'Lottery') THEN b.Odds
								ELSE 0
							END,
					MOdds = CASE 
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'ParlayVS2')  THEN b.modds 
								ELSE 0
							END,
					LiveIndicator = CASE
										WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'ParlayVS2') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.matchid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.matchcode
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE ''
							END,
					HomeId = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.homeid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					Placing = CASE
									WHEN b.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE ''
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('ParlayVS2') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
									WHEN b.Product IN ('CO') AND b.bettype IN (216, 217) THEN ISNULL(b.betcheck, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('CO', 'VS2', 'Keno', 'Lottery') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('CO') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					OriginalBetType = CASE
										WHEN b.Product IN ('CO') THEN b.OriginalBetType
										ELSE 0
									END
				FROM #PagingData AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Product IN ('CO', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
					LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				WHERE b.WhTicket = 2
			END

			-- Get ticket detail
			-- Virtual Sports
			IF EXISTS (SELECT 1 FROM #PagingData WHERE Product = 'VR' AND WhTicket = 1)
			BEGIN
				INSERT INTO @Detail
				SELECT
					bm.refno,
					bm.odds,
					bm.stake * ISNULL(e.Rate, 1) AS Stake,
					bm.status,
					bm.apositiontaking,
					bm.bettype,
					bm.betteam
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN #PagingData AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
					INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
					LEFT JOIN #ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
				WHERE b.Product = 'VR'
					AND b.WhTicket = 1
					AND sbt.ProductID = 5
					AND sbt.EventType = 3
			END

			IF EXISTS (SELECT 1 FROM #PagingData WHERE Product = 'VR' AND WhTicket = 2)
			BEGIN
				INSERT INTO @Detail
				SELECT
					bm.refno,
					bm.odds,
					bm.stake * ISNULL(e.Rate, 1) AS Stake,
					bm.status,
					bm.apositiontaking,
					bm.bettype,
					bm.betteam
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN #PagingData AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
					INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
					LEFT JOIN #ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
				WHERE b.Product = 'VR'
					AND b.WhTicket = 2
					AND sbt.ProductID = 5
					AND sbt.EventType = 3
			END

			-- Return data
			SELECT
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
				a.TransId,
				a.RefNo,
				a.Currency,
				a.CustId,
				a.SportType,
				a.BetType,
				a.BetId,
				a.BetTeam,
				a.Hdp1,
				a.Hdp2,
				a.OddsType,
				a.Odds,
				a.MOdds,
				a.OddsSpread,
				a.Stake * ISNULL(e.Rate, 1) AS Stake,
				a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
				a.WinLost * ISNULL(e.Rate, 1) AS WinLost,
				a.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
				a.Comm * ISNULL(e.Rate, 1) AS Comm,
				a.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
				a.Status,
				a.TransDate,
				a.WinLostDate,
				a.LiveIndicator,
				a.LiveHomeScore,
				a.LiveAwayScore,
				a.Ip,
				a.BetFrom,
				a.LeagueId,
				a.MatchId,
				a.MatchCode,
				a.Race,
				a.HomeId,
				a.AwayId,
				a.IsNeutral,
				a.BetStatus,
				a.Placing,
				a.ShowTime,
				a.BetCheck,
				a.TransDesc,
				a.BetdaqId,
				a.OriginalBetType
			FROM
				#PagingData AS a
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = a.CustId
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
					SportType = CASE
									WHEN b.Product IN ('Keno', 'Lottery') THEN b.MatchId
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'ParlayVS2') THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'ParlayVS2') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('CO', 'VS', 'VS2', 'VR', 'ParlayVS2') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR') THEN b.OddsType
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'Keno', 'ParlayVS2', 'Lottery') THEN b.Odds
								ELSE 0 END,
					MOdds = CASE 
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'ParlayVS2')  THEN b.modds 
								ELSE 0
							END,
					LiveIndicator = CASE
										WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'ParlayVS2') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.matchid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.matchcode
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE ''
							END,
					HomeId = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.homeid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					Placing = CASE
									WHEN b.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE ''
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('ParlayVS2') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
									WHEN b.Product IN ('CO') AND b.bettype IN (216, 217) THEN ISNULL(b.betcheck, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('CO', 'VS2', 'Keno', 'Lottery') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('CO') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					OriginalBetType = CASE
										WHEN b.Product IN ('CO') THEN b.OriginalBetType
										ELSE 0
									END
				FROM #Data AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('CO', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
					LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				WHERE b.WhTicket = 1
			END

			-- bettrans14
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE WhTicket = 2)
			BEGIN
				UPDATE b
				SET
					SportType = CASE
									WHEN b.Product IN ('Keno', 'Lottery') THEN b.MatchId
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'ParlayVS2') THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'ParlayVS2') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('CO', 'VS', 'VS2', 'VR', 'ParlayVS2') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR') THEN b.OddsType
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'Keno', 'ParlayVS2', 'Lottery') THEN b.Odds
								ELSE 0 END,
					MOdds = CASE 
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'ParlayVS2')  THEN b.modds 
								ELSE 0
							END,
					LiveIndicator = CASE
										WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR', 'ParlayVS2') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2', 'VR') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.matchid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.matchcode
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE ''
							END,
					HomeId = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.homeid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('CO', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					Placing = CASE
									WHEN b.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE ''
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('ParlayVS2') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
									WHEN b.Product IN ('CO') AND b.bettype IN (216, 217) THEN ISNULL(b.betcheck, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('CO', 'VS2', 'Keno', 'Lottery') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('CO') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					OriginalBetType = CASE
										WHEN b.Product IN ('CO') THEN b.OriginalBetType
										ELSE 0
									END
				FROM #Data AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Product IN ('CO', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
					LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				WHERE b.WhTicket = 2
			END
			
			CREATE TABLE #Customer (
				CustId		INT,
				Username	VARCHAR(30),
				NickName	VARCHAR(50))

			INSERT INTO #Customer (
				CustId,
				Username,
				NickName)
			SELECT
				custid,
				username,
				SUBSTRING(username2, CHARINDEX('$', username2) + 1, LEN(username2) - CHARINDEX('$', username2)) AS NickName
			FROM dbo.Customer WITH (NOLOCK)
			WHERE custid IN (SELECT DISTINCT CustId FROM #Data)

			-- Get ticket detail
			-- Virtual Sports
			IF EXISTS (SELECT 1 FROM #Data WHERE Product = 'VR' AND WhTicket = 1)
			BEGIN
				INSERT INTO @Detail
				SELECT
					bm.refno,
					bm.odds,
					bm.stake * ISNULL(e.Rate, 1) AS Stake,
					bm.status,
					bm.apositiontaking,
					bm.bettype,
					bm.betteam
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN #Data AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
					INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
					LEFT JOIN #ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
				WHERE b.Product = 'VR'
					AND b.WhTicket = 1
					AND sbt.ProductID = 5
					AND sbt.EventType = 3
			END

			IF EXISTS (SELECT 1 FROM #Data WHERE Product = 'VR' AND WhTicket = 2)
			BEGIN
				INSERT INTO @Detail
				SELECT
					bm.refno,
					bm.odds,
					bm.stake * ISNULL(e.Rate, 1) AS Stake,
					bm.status,
					bm.apositiontaking,
					bm.bettype,
					bm.betteam
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN #Data AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
					INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
					LEFT JOIN #ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
				WHERE b.Product = 'VR'
					AND b.WhTicket = 2
					AND sbt.ProductID = 5
					AND sbt.EventType = 3
			END

			SET @Sql = 
				N'SELECT
					c.Username,
					c.NickName,
					a.TransId,
					a.RefNo,
					a.Currency,
					a.CustId,
					a.SportType,
					a.BetType,
					a.BetId,
					a.BetTeam,
					a.Hdp1,
					a.Hdp2,
					a.OddsType,
					a.Odds,
					a.MOdds,
					a.OddsSpread,
					a.Stake * ISNULL(e.Rate, 1) AS Stake,
					a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
					a.WinLost * ISNULL(e.Rate, 1) AS WinLost,
					a.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
					a.Comm * ISNULL(e.Rate, 1) AS Comm,
					a.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
					a.Status,
					a.TransDate,
					a.WinLostDate,
					a.LiveIndicator,
					a.LiveHomeScore,
					a.LiveAwayScore,
					a.Ip,
					a.BetFrom,
					a.LeagueId,
					a.MatchId,
					a.MatchCode,
					a.Race,
					a.HomeId,
					a.AwayId,
					a.IsNeutral,
					a.BetStatus,
					a.Placing,
					a.ShowTime,
					a.BetCheck,
					a.TransDesc,
					a.BetdaqId,
					a.OriginalBetType
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
	DROP TABLE #Data
	DROP TABLE #ExchangeRate
END
GO





GRANT EXECUTE ON [dbo].[Lrf_BetList_Licensee_Others] TO [bodbLicenseeNet]
GO
