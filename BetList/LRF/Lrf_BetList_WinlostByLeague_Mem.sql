/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_WinlostByLeague_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@Odds			MONEY			= 0,
	@LeagueId		INT,
	@MatchId		INT				= 0,
	@BaseCurrency	VARCHAR(10),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0 OUTPUT,
	@FromDate		SMALLDATETIME	= NULL,
	@ToDate			SMALLDATETIME	= NULL,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@ShowWin		BIT				= 1,
	@ShowLoss		BIT				= 1,
	@ShowDraw		BIT				= 1,
	@ShowSB			BIT				= 1,
	@ShowBA			BIT				= 1
AS

/*
	Created: 20140102@Florent
	Task: Betlist
	DB: DBACC.bodb02
	Original:[Lrf_BetList_MatchWL_Bettype_8828]
	Revisions:
		- 20140207@Florent: add filter ShowBA and ShowSB
		- 20140214@Florent: add filter by match
		- 20140630@Hannah: offer BetRadar and Sporting Solution
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150128@Winnie: Add base currency GBP
		- 20150408@Winnie: Apply spottype bettype matrix & add 60 bettypes betradar
		- 20150608@Edward: Exclude 3 transactions SOLD/BOUGHT/BetTrade Commission of BetTrade
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160714@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20170227@Kos: Support sub licensees [#Redmine: 71679]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]
		- 20170602@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]
		- 20180329@Kos: Support Fast Market 2 [#Redmine: 90879]
		- 20181018@Kos: Support E-Sports 2 [#Redmine: 100721]
					- Move SP from DBEXT to DBACC
		- 20181218@Kos: Add index hint to improve performance [#Redmine: 106553]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190521@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Don't return column ShowTime anymore
		- 20190715@Kos: Hotfix - Show KickOffTime Incorrectly [#Redmine: 116777]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200425@Kos: Support status Delay Payout [Redmine: #132629]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210316@Kos: Support Cricket AIO [Redmine: #148962]
		- 20210323@Kos: Support show IP [Redmine: #151085]

	Param's Explanation: 
		- @AgentList : Agent List, XML format (<ROOT><Agent AgentId="12345" Currency="3"/></ROOT>)
		- @CustID : Customer Number
		- @Odds : decimals odds, default >= 0
		- @LeagueID : LeagueID, Number
		- @PageSize : Number rows of one fage, for faging
		- @PageIndex : Index of paging
		- @TotalRows : Number rows of output
		- @FromDate : time range
		- @ToDate :time range
		- @MoveBetsDay : that day we use bettrans14
		- @BalanceUpDay : that day we use bettrans_bk
		- @ShowWin : show only win bet ,default = 1
		- @ShowLoss: show only loss bet,default = 1
		- @ShowDraw : show only draw bet,default = 1
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
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype INT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)
	WHERE BetType NOT IN (901, 902, 903, 904, 911, 912, 913, 914)

	CREATE TABLE #Data (
		SportType			INT,
		Username			NVARCHAR(50),
		CustId				INT,
		BetType				INT,
		LeagueId			INT,
		TransId				BIGINT,
		MatchCode			VARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		Odds2				MONEY,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		Stake				MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		BetTeam				VARCHAR(50),
		LiveIndicator		INT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		MatchId				INT,
		StatusId			INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		OddsType			INT,
		Ip					NVARCHAR(15),
		BetId				BIGINT,
		Currency			SMALLINT,
		RefNo				BIGINT,
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

	DECLARE @ExchangeRate TABLE (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	DECLARE @Status AS TABLE (StatusID INT)

	IF @ShowWin = 1
	BEGIN
		INSERT INTO @status (StatusID)
		SELECT 112

		INSERT INTO @status (StatusID)
		SELECT 114
	END

	IF @ShowLoss = 1
	BEGIN
		INSERT INTO @status (StatusID)
		SELECT 113

		INSERT INTO @status (StatusID)
		SELECT 115
	END

	IF @ShowDraw = 1
		INSERT INTO @status (StatusID)
		SELECT 111

	DECLARE @SportType	SMALLINT,
		@ParentId		INT

	SELECT
		@SportType = sporttype,
		@ParentId = ParentID
	FROM dbo.match WITH (NOLOCK)
	WHERE matchid = @MatchId AND eventdate > @MoveBetsDay

	IF @SportType IS NULL
	BEGIN
		SELECT
			@SportType = sporttype,
			@ParentId = ParentID
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId AND eventdate BETWEEN @BalanceUpDay AND @MoveBetsDay
	END

	IF @SportType IS NULL
	BEGIN
		SELECT
			@SportType = sporttype,
			@ParentId = ParentID
		FROM bodb_Archive.dbo.match_bk WITH (NOLOCK)
		WHERE matchid = @MatchId AND eventdate < @BalanceUpDay
	END

	DECLARE @Match TABLE(MatchId INT)

	IF @SportType = 50 AND @ParentId IS NULL	-- Cricket, parent match
	BEGIN
		INSERT INTO @Match
		SELECT DISTINCT MatchId
		FROM dbo.match WITH (NOLOCK)
		WHERE ParentID = @MatchId
			AND sporttype = @SportType
			AND eventdate BETWEEN @FromDate AND @ToDate
			AND ChildMatchType = 200
		UNION
		SELECT DISTINCT MatchId
		FROM dbo.match14 WITH (NOLOCK)
		WHERE ParentID = @MatchId
			AND sporttype = @SportType
			AND eventdate BETWEEN @FromDate AND @ToDate
			AND ChildMatchType = 200
		UNION
		SELECT DISTINCT MatchId
		FROM bodb_Archive.dbo.match_bk WITH (NOLOCK)
		WHERE ParentID = @MatchId
			AND sporttype = @SportType
			AND eventdate BETWEEN @FromDate AND @ToDate
			AND ChildMatchType = 200
	END

	DECLARE @TempFromDate SMALLDATETIME
	DECLARE @TempToDate SMALLDATETIME

	-- bettrans
	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		IF 1 IN (@ShowBA, @ShowSB)
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				b.hdp1,
				b.hdp2,
				b.odds,
				CASE
					WHEN ( b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120 )
						THEN CASE
								WHEN b.oddstype = 1 THEN b.odds + 1 --decimal
								WHEN b.oddstype = 2 THEN b.odds + 1 --hongkong to decimal
								WHEN b.oddstype IN (3, 4) THEN --malay and indo to decimal
									CASE
										WHEN b.odds < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN b.odds >= 0 THEN (1 + b.odds)
									END
								WHEN b.oddstype = 5 THEN --american odds to decimal
									CASE
										WHEN (b.odds * 100) < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN (b.odds * 100) % 2 = 0 THEN 2
										WHEN (b.odds * 100) > 0 THEN (1 + b.odds)
									END
								END
					ELSE b.odds
				END AS odds2,
				b.status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE -(b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				b.statusID,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				b.oddstype,
				b.ip,
				b.betid,
				b.currency,
				b.refno,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
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
				b.ip,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE ISNULL(b.WalletType, 0)
				END AS WalletType,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE ISNULL(b.RefCode, 0)
				END AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_custid)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @TempAg AS ta ON b.recommend = ta.custid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE m.leagueid = @LeagueId
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (SELECT StatusID FROM @Status)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.custid = @CustId
				AND 1 = CASE
							WHEN b.tpositiontaking = 0 AND @ShowBA = 1 THEN 1
							WHEN b.tpositiontaking <> 0 AND @ShowSB = 1 THEN 1
							ELSE 0
						END
				AND (@MatchId = 0
					OR m.matchid = @MatchId
					OR m.matchid IN (SELECT MatchId FROM @Match))
		END
	END

	-- bettrans14
	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF 1 IN (@ShowBA, @ShowSB)
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.GlobalShowTime AS EventDate,
				m.homeID,
				m.awayID,
				b.hdp1,
				b.hdp2,
				b.Odds,
				CASE
					WHEN ( b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120 )
						THEN CASE 
								WHEN b.oddstype = 1 THEN b.odds + 1 --decimal
								WHEN b.oddstype = 2 THEN b.Odds + 1 --hongkong to decimal
								WHEN b.oddstype IN (3, 4) THEN --malay and indo to decimal
									CASE 
										WHEN b.odds < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN b.odds >= 0 THEN (1 + b.odds)
									END
								WHEN b.oddstype = 5 THEN --american odds to decimal
									CASE 
										WHEN (b.odds * 100) < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN (b.odds * 100) % 2 = 0 THEN 2
										WHEN (b.odds * 100) > 0 THEN (1 + b.odds)
									END
							END
					ELSE b.odds
				END odds2,
				b.status,
				0 AS SettlementStatus,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE -(b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				b.statusID,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				b.oddstype,
				b.ip,
				b.betid,
				b.currency,
				b.refno,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
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
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE ISNULL(b.WalletType, 0)
				END AS WalletType,
				b.ip,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE ISNULL(b.RefCode, 0)
				END AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @TempAg AS ta ON b.recommend = ta.custid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE m.leagueid = @LeagueId
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (SELECT StatusID FROM @Status)
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustId
				AND 1 = CASE
							WHEN b.tpositiontaking = 0 AND @ShowBA = 1 THEN 1
							WHEN b.tpositiontaking <> 0 AND @ShowSB = 1 THEN 1
							ELSE 0
						END
				AND (@MatchId = 0
					OR m.matchid = @MatchId
					OR m.matchid IN (SELECT MatchId FROM @Match))
		END
	END

	-- bettrans_bk
	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @todate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @todate

		IF 1 IN (@ShowBA, @ShowSB)
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				'' AS Username,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				b.hdp1,
				b.hdp2,
				b.odds,
				CASE
					WHEN ( b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120 )
						THEN CASE
								WHEN b.oddstype = 1 THEN b.odds + 1 --decimal
								WHEN b.oddstype = 2 THEN b.odds + 1 --hongkong to decimal
								WHEN b.oddstype IN (3, 4) THEN --malay and indo to decimal
									CASE
										WHEN b.odds < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN b.odds >= 0 THEN (1 + b.odds)
									END
								WHEN b.oddstype = 5 THEN --american odds to decimal
									CASE
										WHEN (b.odds * 100) < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN (b.odds * 100) % 2 = 0 THEN 2
										WHEN (b.odds * 100) > 0 THEN (1 + b.odds)
									END
								END
					ELSE b.odds
				END AS odds2,
				b.status,
				0 AS SettlementStatus,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE -(b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				b.statusID,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				b.oddstype,
				b.ip,
				b.betid,
				b.currency,
				b.refno,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
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
				b.ip,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE ISNULL(b.WalletType, 0)
				END AS WalletType,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE ISNULL(b.RefCode, 0)
				END AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @TempAg AS ta ON b.recommend = ta.custid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE m.leagueid = @LeagueId
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (SELECT StatusID FROM @Status)
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustId
				AND 1 = CASE
							WHEN b.tpositiontaking = 0 AND @ShowBA = 1 THEN 1
							WHEN b.tpositiontaking <> 0 AND @ShowSB = 1 THEN 1
							ELSE 0
						END
				AND (@MatchId = 0
					OR m.matchid = @MatchId
					OR m.matchid IN (SELECT MatchId FROM @Match))
		END
	END

	DELETE #Data
	WHERE odds2 < @Odds

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode		BIGINT,
			TransId		BIGINT,
			Stake		MONEY,
			WinLost		MONEY,
			LicenseeWL	MONEY,
			Comm		MONEY,
			PlayerComm	MONEY
		)

		-- Prepare temp table
		INSERT INTO @RefCodeTmp
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake,
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

	SELECT @TotalRows = COUNT(1)
	FROM #Data

	DECLARE @Currency	INT

	SELECT @Currency = currency
	FROM dbo.Customer WITH (NOLOCK)
	WHERE custid = @CustId

	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM #Data

	-- Get exchange rate
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
	WHERE e.ExchangeId = @Currency
		AND EXISTS (SELECT 1 FROM #Data WHERE WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)

	DECLARE @RowStart	INT,
		@RowEnd			INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	SELECT A.*
	FROM (
		SELECT
			ROW_NUMBER() OVER (ORDER BY b.Status ASC, b.TransDate ASC) AS RowNum,
			b.SportType,
			b.Username,
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
			b.CustId,
			b.BetType,
			b.LeagueId,
			b.TransId,
			b.MatchCode,
			b.EventDate,
			b.HomeId,
			b.AwayId,
			b.Hdp1,
			b.Hdp2,
			b.Odds,
			b.Odds2,
			b.Status,
			b.SettlementStatus,
			b.Stake * ISNULL(e.Rate, 1) AS Stake,
			b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
			b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
			b.Comm * ISNULL(e.Rate, 1) AS Comm,
			b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
			b.TransDate,
			b.WinLostDate,
			b.BetTeam,
			b.LiveIndicator,
			b.LiveHomeScore,
			b.LiveAwayScore,
			b.MatchId,
			b.StatusId,
			b.BetStatus,
			b.IsNeutral,
			b.OddsType,
			b.Ip,
			b.BetId,
			b.Currency,
			b.RefNo,
			b.BetCheck,
			b.TransDesc,
			b.BetdaqId,
			b.ExtraInfo,
			b.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
			b.OriginalBetType,
			b.WalletType,
			b.RefCode,
			OddsSpread
		FROM #Data AS b
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid
			LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #Data
END
GO
