/*<info serverAlias="DBBOF-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_SelRunningByBettypeList]
	@AgentList		VARCHAR(MAX),
	@BetType		VARCHAR(50),
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0 OUTPUT
AS

/*
	Created: Hannah@20140708
	Task: Betlist
	DB: DBBOF.bodb02
	Original: [Lrf_BetList_SelRunningByBettype]
	Revisions:
		- 20140708@Hannah: Clone from Lrf_BetList_SelRunningByBettype to support muilti bettype
		- 20140925@Jim: Restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
		- 20150123@Jim: Support base on Currency GBP
		- 20150414@Jim: Support betradar
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160412@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20161003@Kos: Remove Live Casino code [Redmine: #65045]
		- 20170223@Kos: Support sub licensees [#Redmine: 71679]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]
		- 20170529@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180801@Kos: Migrate to DB042 [#Redmine: 99020]
		- 20181012@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 107165]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190520@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
		- 20190715@Kos: Hotfix - Show KickOffTime Incorrectly [#Redmine: 116777]
		- 20190729@Kos: Support new status Pending [#Redmine: 117729]
		- 20191029@Kos: Show Running status for Marked tickets [Redmine: 120309]
		- 20191226@Kos: Support Bet Builder [Redmine: #108298]
		- 20201123@Kos: Support God Of Fortune [Redmine: #145832]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20230922@Kos: Support crypto currency [Redmine: 177481]
		- 20251028@Kelvin: Integrate - Jacktime - Basketball Main Bettype Hybrid Parlay [#Redmine: 242357]
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

	IF ISNULL(@BetType, '') = ''
		SET @BetType = ''

	CREATE TABLE #Data (
		CustId				INT,
		SportType			INT,
		Username			NVARCHAR(50),
		BetType				SMALLINT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				BIGINT,
		MatchCode			VARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		MOdds				MONEY,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				VARCHAR(50),
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		LiveIndicator		INT,
		Discount			DECIMAL(9,8),
		LeagueId			INT,
		Ip					VARCHAR(45),
		IsNeutral			BIT,
		OddsType			TINYINT,
		Currency			SMALLINT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY
	)

	INSERT INTO #Data
	(
		CustId, SportType, Username, BetType, TransId, BetId, RefNo, MatchCode, EventDate, HomeId,
		AwayId, Hdp1, Hdp2, Odds, MOdds, Status, SettlementStatus, Stake, Actual_Stake, TransDate,
		BetTeam, LiveHomeScore, LiveAwayScore, LiveIndicator, Discount, LeagueId, Ip, IsNeutral, OddsType, Currency,
		ShowTime, BetCheck, BetdaqId, ExtraInfo, OriginalStake, OriginalBetType, WalletType, RefCode, TransDesc, OddsSpread
	)
	SELECT
		b.custid,
		0 AS SportType,
		b.username,
		b.bettype,
		b.transid,
		ISNULL(b.betid, 0),
		b.refno,
		'' AS matchcode,
		b.winlostdate AS EventDate,
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
								WHERE bm.custid = b.custid
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
		0 AS livehomescore,
		0 AS liveawayscore,
		0 AS liveindicator,
		b.discount,
		0 AS LeagueID,
		b.ip,
		CONVERT(BIT,0) AS IsNeutral,
		0 AS oddstype,
		b.currency,
		'' AS ShowTime,
		ISNULL(b.betcheck, '') AS BetCheck,
		-1 AS BetdaqId,
		ISNULL(b.ExtraInfo, '') AS ExtraInfo,
		0 AS OriginalStake,
		0 AS OriginalBetType,
		0 AS WalletType,
		0 AS RefCode,
		ISNULL(b.transdesc, '') AS TransDesc,
		ISNULL(b.oddsspread, 0) AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE
		b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
		AND ',' + @BetType + ',' LIKE '%,' + CONVERT(VARCHAR(5), b.bettype) + ',%'
		AND b.bettype IN (9, 29)
		AND b.matchid = b.bettype
		AND b.statusID IN (0, 1)

	INSERT INTO #Data
	(
		CustId, SportType, Username, BetType, TransId, BetId, RefNo, MatchCode, EventDate, HomeId,
		AwayId, Hdp1, Hdp2, Odds, MOdds, Status, SettlementStatus, Stake, Actual_Stake, TransDate,
		BetTeam, LiveHomeScore, LiveAwayScore, LiveIndicator, Discount, LeagueId, Ip, IsNeutral, OddsType, Currency,
		ShowTime, BetCheck, BetdaqId, ExtraInfo, OriginalStake, OriginalBetType, WalletType, RefCode, TransDesc, OddsSpread
	)
	SELECT
		b.custid,
		m.sporttype,
		b.username,
		b.bettype,
		b.transid,
		ISNULL(b.betid, 0),
		b.refno,
		m.matchcode,
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
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator,
		b.discount,
		m.leagueid,
		b.ip,
		ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.oddstype,
		b.currency,
		ISNULL(m.showtime, '') AS showtime,
		b.betcheck,
		ISNULL(b.betdaqid, -1) AS BetdaqId,
		ISNULL(b.ExtraInfo, '') AS ExtraInfo,
		CASE
			WHEN b.ExtraInfo LIKE '%p25%' THEN
				ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]', 'MONEY'), 0)
			ELSE 0
		END AS OriginalStake,
		CASE
			WHEN b.stake <> 0 THEN -1
			ELSE 0
		END AS OriginalBetType,
		ISNULL(b.WalletType, 0) AS WalletType,
		ISNULL(b.RefCode, 0) AS RefCode,
		ISNULL(b.transdesc, '') AS TransDesc,
		ISNULL(b.oddsspread, 0) AS OddsSpread
	FROM
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
	WHERE
		b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
		AND ',' + @BetType + ',' LIKE '%,' + CONVERT(VARCHAR(5), b.bettype) + ',%'
		AND b.statusID IN (0, 1)

	-- Get original odds and final odds for Mix Parlay
	--============================================================================================================================================
	IF EXISTS (SELECT 1 FROM #Data b WHERE b.BetType = 29 AND b.BetTeam = '1')
	BEGIN
		-- Running
		;WITH CTE_Update AS
		(
			SELECT b.TransId, TRY_CAST(b.ExtraInfo AS XML).value('(/p1/@o)[1]', 'MONEY') AS OriginalOdds
			FROM #Data b
			WHERE b.BetType = 29 AND b.BetTeam = '1' AND b.Status IN ('Running', 'Waiting')
		)
		UPDATE b
		SET
			b.Odds = ISNULL(t.OriginalOdds, 0),
			b.Modds = ISNULL(t.OriginalOdds, 0)
		FROM #Data AS b
			INNER JOIN CTE_Update t ON t.TransId = b.TransId

		-- Settled
		;WITH CTE_Update AS
		(
			SELECT b.TransId, TRY_CAST(b.ExtraInfo AS XML).value('(/p1/@o)[1]', 'MONEY') AS OriginalOdds
			FROM #Data b
			WHERE b.BetType = 29 AND b.BetTeam = '1' AND b.Status NOT IN ('Running', 'Waiting')
		)
		UPDATE b
		SET
			b.Odds = ISNULL(t.OriginalOdds, bpr.Odds),
			b.Modds = CASE 
						WHEN bpr.statusid = 113 AND bpr.mOdds = 0 THEN ISNULL(t.OriginalOdds, bpr.Odds)
						ELSE bpr.mOdds 
					END
		FROM #Data AS b
			INNER JOIN CTE_Update t ON t.TransId = b.TransId
			INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
	END
	--============================================================================================================================================

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode			BIGINT,
			TransId			BIGINT,
			Stake			MONEY,
			Actual_Stake	MONEY
		)

		-- Prepare temp table
		INSERT INTO @RefCodeTmp (RefCode, TransId, Stake, Actual_Stake)
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake,
			SUM(Actual_Stake) AS Actual_Stake
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

	-- Get total rows
	SELECT @TotalRows = COUNT(transid)
	FROM #Data

	-- Get exchange rate
	CREATE TABLE #ExchangeRate (
		ExchangeId	INT,
		Rate		FLOAT
	)

	IF @TotalRows > 0
	BEGIN
		INSERT INTO #ExchangeRate (ExchangeId, Rate)
		SELECT
			e.ExchangeId,
			e.Rate
		FROM dbo.Lrf_f_GetExchangeRate(DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), @BaseCurrency, '') AS e
		WHERE EXISTS (SELECT 1 FROM #Data WHERE Currency = e.ExchangeId)
	END

	DECLARE @RowStart	INT,
		@RowEnd			INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	SELECT
		a.RowNum,
		a.Nickname,
		a.CustId,
		a.SportType,
		a.Username,
		a.BetType,
		a.TransId,
		a.BetId,
		a.RefNo,
		a.MatchCode,
		a.EventDate,
		a.HomeId,
		a.AwayId,
		a.Hdp1,
		a.Hdp2,
		a.Odds,
		a.MOdds,
		a.Status,
		a.SettlementStatus,
		a.Stake,
		a.Actual_Stake,
		a.TransDate,
		a.BetTeam,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.LiveIndicator,
		a.Discount,
		a.LeagueId,
		a.Ip,
		a.IsNeutral,
		a.OddsType,
		a.Currency,
		a.ShowTime,
		a.BetCheck,
		a.BetdaqId,
		a.ExtraInfo,
		a.OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode,
		a.TransDesc,
		a.OddsSpread
	FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.TransId ASC) AS RowNum,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
				b.CustId,
				b.SportType,
				b.Username,
				b.BetType,
				b.TransId,
				b.BetId,
				b.RefNo,
				b.MatchCode,
				b.EventDate,
				b.HomeId,
				b.AwayId,
				b.Hdp1,
				b.Hdp2,
				b.Odds,
				b.MOdds,
				b.Status,
				b.SettlementStatus,
				b.Stake * ISNULL(e.Rate, 1) AS Stake,
				b.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
				b.TransDate,
				b.BetTeam,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.LiveIndicator,
				b.Discount,
				b.LeagueId,
				b.Ip,
				b.IsNeutral,
				b.OddsType,
				b.Currency,
				b.ShowTime,
				b.BetCheck,
				b.BetdaqId,
				b.ExtraInfo,
				b.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
				b.OriginalBetType,
				b.WalletType,
				b.RefCode,
				b.TransDesc,
				b.OddsSpread
			FROM #Data AS b
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.CustId
				LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = b.currency
		) a
	WHERE a.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #Data
	DROP TABLE #ExchangeRate
END
GO
