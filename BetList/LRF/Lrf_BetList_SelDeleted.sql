USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelDeleted_xtest]    Script Date: 11/29/2014 09:42:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelDeleted]
	@AgentList	VARCHAR(MAX),
	@CustId		INT,
	@PageSize	INT				= 1000,
	@PageIndex	INT				= 1,
	@TotalRows	INT				= 0 OUTPUT
AS

/*
	Create: Henry@20101210
	DB: DBEXT.bodb02
	Original: Age_BetList_SelDeleted 

	Revisions:
		- 20110216@Jacob: Add column nickname in the result SET
		- 20110303@Henry: suppport based currency
		- 20110408@Amy: Change function to get Odds value AND odds type
		- 20110714@Henry: remove apositiontaking
		- 20110729@Henry: offer 3 new bettypes for Number Game
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120816@Henry: add ShowLiveCasino
		- 20130411@Jim: support base currency
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20140403@Hannah: offer Keno
		- 20140521@Jim: fix bug not show outright tikect (bug #16525)
		- 20140925@Jim: restrict Virtual Horse Racing bettype (hot fix #22012)
		- 20141129@Jim: add more param @CurrencyID
		- 20150128@Winnie: add base currency GBP
		- 20150409@Winnie: Apply spottype bettype matrix & 60 bettypes betradar
		- 20150423@Jim: fix bug
		- 20150609@Edward: Support BetTrade
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160714@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160913@Kos: Don't support Colossus Bets [#Redmine: 63785]
		- 20161005@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170228@Kos: Support sub licensees [#Redmine: 71679]
		- 20170303@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170329@Kos: Support CashOut [#Redmine: 71963]
		- 20170605@Kos: Get liveindicator from original ticket for 911 and 912 tickets [#Redmine: 77669]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170628@Kos: Hotfix - CashOut Details link in Racing tickets [#Redmine: 79076]
		- 20170721@Kos: Support Keno Lottery [#Redmine: 79997]
		- 20170830@Kos: Support Licensee Bonus System [#Redmine: 72792]

	Param's Explanation:
		- @AgentList: Agent List, XML format (<ROOT><Agent AgentId="12345" Currency="3"/></ROOT>)
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

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID INT, Bettype INT, EventType INT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID <= 6 OR ProductID IN (8, 25, 27, 28)

	DELETE FROM @SportBettype
	WHERE Bettype IN (904, 914)

	CREATE TABLE #Data (
		SportType		SMALLINT,
		Username		NVARCHAR(50),
		CustId			INT,
		TransId			BIGINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		RefNo			NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		BetTeam			NVARCHAR(50),
		BetType			SMALLINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(50),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(50),
		EventDate		DATETIME,
		Ip				VARCHAR(30),
		IsNeutral		BIT,
		BetId			BIGINT,
		Currency		SMALLINT,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		WalletType		TINYINT,
		RefCode			BIGINT
	)

	-- Keno, Lottery
	INSERT INTO #Data
	SELECT
		CASE
			WHEN sbt.ProductID = 8 THEN 202
			WHEN sbt.ProductID = 28 THEN 220
			ELSE 0
		END AS SportType,
		b.Username,
		b.custid,
		b.transid,
		b.transdate,
		b.winlostdate,
		b.refno,
		0 AS HomeID,
		0 AS AwayID,
		'' AS betteam,
		b.bettype,
		0 AS Hdp1,
		0 AS Hdp2,
		0 AS MOdds,
		0 AS OddsYype,
		b.odds,
		b.stake,
		b.status,
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		0 AS LeagueId,
		0 AS MatchId,
		'' AS matchcode,
		'' AS Race,
		b.winlostdate AS eventdate,
		b.ip,
		CONVERT(BIT,0) AS IsNeutral,
		b.betid,
		b.currency,
		'' AS ShowTime,
		'' AS betcheck,
		ISNULL(b.transdesc, '') AS transdesc,
		-1 AS BetdaqId,
		'' AS ExtraInfo,
		0 AS OriginalStake,
		0 AS OriginalBetType,
		0 AS WalletType,
		0 AS RefCode
	FROM
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
	WHERE
		b.custid = @CustID
		AND b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
		AND b.statusID IN (101, 102)
		AND b.winlostdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
		AND sbt.productId IN (8, 28)
		AND b.ruben = 1

	-- Others
	INSERT INTO #Data
	SELECT
		m.sporttype,
		b.Username,
		b.custid,
		b.transid,
		b.transdate,
		b.winlostdate,
		b.refno,
		m.homeid,
		m.awayid,
		b.betteam,
		b.bettype,
		b.hdp1,
		b.hdp2,
		b.modds,
		b.oddstype,
		b.odds,
		b.stake,
		b.status,
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		m.leagueid,
		m.matchid,
		m.matchcode,
		'' AS Race,
		m.eventdate,
		b.ip,
		ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.betid,
		b.currency,
		CASE
			WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
			ELSE ''
		END AS ShowTime,
		b.betcheck,
		ISNULL(b.transdesc, '') AS transdesc,
		CASE
			WHEN sbt.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
			ELSE -1
		END AS BetdaqId,
		ISNULL(b.ExtraInfo, '') AS ExtraInfo,
		CASE
			WHEN sbt.ProductID = 1 AND b.ExtraInfo LIKE '%p25%' THEN
				ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
			ELSE 0
		END AS OriginalStake,
		0 AS OriginalBetType,
		CASE
			WHEN sbt.ProductID = 1 THEN ISNULL(b.WalletType, 0)
			ELSE 0
		END AS WalletType,
		CASE
			WHEN sbt.ProductID = 1 THEN ISNULL(b.RefCode, 0)
			ELSE 0
		END AS RefCode
	FROM
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN
			(	SELECT
					sporttype,
					homeid,
					awayid,
					leagueid,
					matchid,
					matchcode,
					eventdate,
					isneutral,
					showtime,
					kickofftime
				FROM dbo.match WITH (NOLOCK)
				WHERE eventdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
			) AS m ON b.matchid = m.matchid
		INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
	WHERE
		b.custid = @CustID
		AND b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
		AND b.statusID IN (101, 102)
		AND sbt.ProductID != 8
		AND b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())

	-- Outright/Horse Racing
	UNION ALL
	SELECT
		l.sporttype,
		b.Username,
		b.custid,
		b.transid,
		b.transdate,
		b.winlostdate,
		b.refno,
		m.homeid,
		0 AS AwayID,
		'' AS Betteam,
		b.bettype,
		0 AS Hdp1,
		0 AS Hdp2,
		b.modds,
		0 AS OddsType,
		b.odds,
		b.stake,
		b.status,
		0 AS Liveindicator,
		0 AS Livehomescore,
		0 AS Liveawayscore,
		m.leagueid,
		b.matchid,
		m.matchcode,
		m.groupmatch AS Race,
		m.eventdate,
		b.ip,
		CONVERT(BIT,0) AS IsNeutral,
		b.betid,
		b.currency,
		'' AS ShowTime,
		'' AS betcheck,
		'' AS transdesc,
		-1 AS BetdaqId,
		'' AS ExtraInfo,
		0 AS OriginalStake,
		0 AS OriginalBetType,
		0 AS WalletType,
		0 AS RefCode
	FROM
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN
			(	SELECT 
					teamid AS homeid,
					leagueid,
					orid,
					matchcode,
					groupmatch,
					eventdate
				FROM dbo.outright WITH (NOLOCK)
				WHERE eventdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
			) AS m ON b.matchid = m.orid
		INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
		INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
	WHERE
		(sbt.ProductID = 2
			OR (sbt.ProductID = 1 AND sbt.EventType = 2))
		AND b.custid = @CustID
		AND b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
		AND b.statusID IN (101, 102)

	-- Virtual Horse Racing
	UNION ALL
	SELECT
		vhr.Sporttype,
		b.Username,
		b.custid,
		b.transid,
		b.transdate,
		b.winlostdate,
		b.refno,
		vhr.homeid,
		0 AS AwayID,
		'' AS Betteam,
		b.bettype,
		0 AS Hdp1,
		0 AS Hdp2,
		b.modds,
		0 AS OddsType,
		b.odds,
		b.stake,
		b.status,
		0 AS Liveindicator,
		0 AS Livehomescore,
		0 AS Liveawayscore,
		vhr.LeagueID,
		vhr.EventID AS matchid,
		vhr.matchcode,
		vhr.groupmatch AS Race,
		vhr.eventdate,
		b.ip,
		CONVERT(BIT,0) AS IsNeutral,
		b.betid,
		b.currency,
		CONVERT(NVARCHAR(50), vhr.EventTime) AS ShowTime,
		'' AS betcheck,
		'' AS transdesc,
		-1 AS BetdaqId,
		'' AS ExtraInfo,
		0 AS OriginalStake,
		0 AS OriginalBetType,
		0 AS WalletType,
		0 AS RefCode
	FROM 
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
		INNER JOIN
			(	SELECT
					vsr.SportType,
					vso.RacerID AS homeid,
					vsr.LeagueID,
					vsr.EventID,
					vso.Orid,
					CONVERT(VARCHAR(20), vso.RacerNum) AS matchcode,
					'' groupmatch,
					vso.EventDate,
					vsr.EventTime
				FROM dbo.VSOutright AS vso WITH (NOLOCK) 
					INNER JOIN dbo.VSRaceInfo AS vsr WITH (NOLOCK) ON vso.EventID = vsr.EventID
				WHERE vso.EventDate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
			) AS vhr ON b.oddsid = vhr.Orid
	WHERE
		sbt.ProductID = 5
		AND sbt.EventType = 3
		AND b.custid = @CustID
		AND b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
		AND b.statusID IN (101, 102)

	-- Get more info for BetTrade tickets
	IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType IN (901, 902))
	BEGIN
		UPDATE betList
		SET betList.Odds = originBetList.Odds,
			betList.Stake = originBetList.Stake,
			betList.LiveHomeScore = originBetList.livehomescore,
			betList.LiveAwayScore = originBetList.liveawayscore,
			betList.betid = originBetList.Bettype
		FROM #Data AS betList
			INNER JOIN dbo.bettrans AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.transid
		WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)
	END

	-- Get more info for CashOut tickets
	IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 911)
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
		WHERE b.BetType = 911
	END

	IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 912)
	BEGIN
		UPDATE b
		SET b.Odds = ob.odds,
			b.LiveIndicator = ob.liveindicator,
			b.LiveHomeScore = ob.livehomescore,
			b.LiveAwayScore = ob.liveawayscore,
			b.OriginalBetType = ob.bettype,
			b.BetdaqId = ob.transid,
			b.Stake = cob.stake
		FROM #Data AS b
			INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
			INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
			LEFT JOIN #Data AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
		WHERE b.BetType = 912
	END

	DELETE #Data
	WHERE BetType IN (903, 913)

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode	BIGINT,
			TransId	BIGINT,
			Stake	MONEY
		)

		-- Prepare temp table
		INSERT INTO @RefCodeTmp
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake
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

	DECLARE @Fromdate	DATETIME,
		@Todate			DATETIME

	SELECT @FromDate = MIN(winlostdate) FROM #Data
	SELECT @ToDate = MAX(winlostdate) FROM #Data

	IF @TotalRows = 0
	BEGIN
		SELECT @TotalRows = COUNT(transid) FROM #Data
	END

	CREATE NONCLUSTERED INDEX IDX_Index_Data ON #Data (Currency)

	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	SELECT A.* 
	FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.EventDate, b.MatchId, b.CustId, b.TransId DESC) AS RowNum,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
				b.*,
				b.Stake * e.USD AS StakeUSD,
				b.Stake * e.EUR AS StakeEUR,
				b.Stake * e.GBP AS StakeGBP,
				b.OriginalStake * e.USD AS OriginalStakeUSD,
				b.OriginalStake * e.EUR AS OriginalStakeEUR,
				b.OriginalStake * e.GBP AS OriginalStakeGBP
			FROM #Data AS b
				INNER JOIN dbo.customer AS c WITH (NOLOCK) ON c.custid = b.CustId
				INNER JOIN #TempExchange AS e
					ON e.ExchangeDate = (CASE WHEN b.WinLostDate > @Todate THEN @Todate ELSE b.WinLostDate END) AND e.exchangeid = b.Currency
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
		StakeGBP		MONEY)

	-- Horse Racing
	IF EXISTS (	SELECT TOP(1) 1
				FROM #Data AS b
					INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
				WHERE sbt.ProductID = 2)
	BEGIN
		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR AS StakeEUR,
			bm.stake * e.USD AS StakeUSD,
			bm.stake * e.GBP AS StakeGBP
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #Data AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE sbt.ProductId = 2 AND sbtm.ProductId = 2
	END

	-- Live Casino
	IF EXISTS (	SELECT TOP(1) 1
				FROM #Data AS b
					INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
				WHERE sbt.ProductID = 4)
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
			bg.stake * e.EUR AS StakeEUR,
			bg.stake * e.USD AS StakeUSD,
			bg.stake * e.GBP AS StakeGBP
		FROM dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN #Data AS b ON bg.refno = b.RefNo AND bg.custid = b.CustId
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.BetType
			INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
		WHERE sbt.ProductID = 4 AND sbtg.ProductId = 4
	END

	-- Virtual Sports
	IF EXISTS (	SELECT TOP 1 1
				FROM #Data AS b
					INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.BetType
				WHERE sbt.ProductID = 5 AND sbt.EventType = 3)
	BEGIN
		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR AS StakeEUR,
			bm.stake * e.USD AS StakeUSD,
			bm.stake * e.GBP AS StakeGBP
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #Data AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE sbt.ProductID = 5
			AND sbt.EventType = 3
			AND sbtm.ProductID = 5
			AND sbtm.EventType = 3
	END 

	SELECT * FROM @BettransDetail
	ORDER BY RefNo, Bettype

	DROP TABLE #TempExchange
	DROP TABLE #Data
END




GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelDeleted] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelDeleted] TO [vnteam]
GO
