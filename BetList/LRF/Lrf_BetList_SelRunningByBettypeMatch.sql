/*<info serverAlias="DBBOF-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_SelRunningByBettypeMatch]
	@AgentList		VARCHAR(MAX),
	@MatchId		INT,
	@BetType		INT,
	@BetTeam		VARCHAR(20)	= NULL,
	@LiveIndicator	INT			= -1,
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT			= 1000,
	@PageIndex		INT			= 1,
	@TotalRows		INT			= 0 OUTPUT
AS

/*
	Created: Henry@20101209
	Task: Betlist
	DB: DBBOF.bodb02
	Original: [Age_BetList_SelRunningByBettypeMatch_Ag]
	Revisions:
		- 20110216@Jacob: Add column nickname IN the result SET
		- 20110303@Henry: suppport based currency
		- 20110408@Amy: Change function to get Odds value AND odds type
		- 20110513@Henry: change bettype to new range
		- 20110630@Henry: add column discount
		- 20110714@Henry: remove apositiontaking
		- 20110729@Henry: offer 3 new bettypes for Number Game
		- 20110819@Henry: exclude BA tickets
		- 20111122@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
		- 20111212@Jim: change condition bettype<19000
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20120706@Jim: get sporttype for Outright
		- 20120726@Jim: add playercomm value
		- 20120817@Henry: add live casino
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20130411@Jim: support base currency USD
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20140925@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust 
		- 20150124@Winnie: Add base currency GBP
		- 20150414@Jim: support betradar
		- 20150630@Jim: remove BA ticket
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20161003@Kos: Remove Live Casino code
		- 20170223@Kos: Support sub licensees [#Redmine: 71679]
		- 20170324@Kos: Support CashOut [#Redmine: 71963]
		- 20170529@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180801@Kos: Migrate to DB042 [#Redmine: 99020]
		- 20181012@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190520@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
		- 20190715@Kos: Hotfix - Show KickOffTime Incorrectly [#Redmine: 116777]
		- 20190729@Kos: Support new status Pending [#Redmine: 117729]
		- 20191029@Kos: Show Running status for Marked tickets [Redmine: 120309]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20230922@Kos: Support crypto currency [Redmine: 177481]
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

	SET @BetTeam = RTRIM(LTRIM(ISNULL(@BetTeam, '')))

	CREATE TABLE #Data (
		CustId				INT,
		SportType			INT,
		Username			NVARCHAR(50),
		BetType				SMALLINT,
		TransId				BIGINT,
		MatchCode			VARCHAR(50),
		Race				VARCHAR(50),
		EventDate			DATETIME,
		LeagueId			INT,
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				VARCHAR(50),
		LiveIndicator		INT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Discount			DECIMAL(9,8),
		Ip					VARCHAR(45),
		IsNeutral			BIT,
		OddsType			TINYINT,
		BetId				BIGINT,
		Currency			SMALLINT,
		RefNo				BIGINT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT
	)

	IF @BetType = 10
	BEGIN
		INSERT INTO #Data
		SELECT
			b.custid,
			l.sporttype,
			b.Username,
			b.bettype,
			b.transid,
			m.matchcode,
			m.groupmatch AS Race,
			b.winlostdate AS EventDate,
			m.leagueid,
			m.teamid AS HomeID,
			0 AS AwayId,
			0 AS hdp1,
			0 AS hdp2,
			b.odds,
			b.status,
			0 AS SettlementStatus,
			b.stake,
			b.actual_stake,
			b.Transdate,
			'' AS Betteam,
			0 AS Liveindicator,
			0 AS Livehomescore,
			0 AS Liveawayscore,
			b.discount,
			b.ip,
			CONVERT(BIT,0) AS isNeutral,
			0 AS oddstype,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime,
			'' AS betcheck,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
		WHERE
			b.matchid = @MatchId
			AND b.bettype = @BetType
			AND b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
			AND b.statusID IN (0, 1)
	END
	ELSE IF @BetType <= 19000
	BEGIN
		INSERT INTO #Data
		SELECT
			b.custid,
			m.sporttype,
			b.Username,
			b.bettype,
			b.transid,
			m.matchcode,
			'' AS Race,
			m.GlobalShowTime AS EventDate,
			m.leagueid,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.discount,
			b.ip,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.oddstype,
			b.betid,
			b.currency,
			b.refno,
			ISNULL(m.showtime, '') AS showtime,
			b.betcheck,
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
			ISNULL(b.RefCode, 0) AS RefCode
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE
			b.matchid = @MatchId
			AND b.bettype = @BetType
			AND b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
			AND b.statusID IN (0, 1)
			AND ((@LiveIndicator = -1)
				OR (@LiveIndicator = 0 AND b.liveindicator = 0)
				OR (@LiveIndicator = 1 AND b.liveindicator = 1))
			AND ((@BetTeam = '')
				OR (@BetTeam <> '' AND b.betteam = @BetTeam))
			AND b.tpositiontaking <> 0
	END

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
		INSERT INTO @RefCodeTmp
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
		INSERT INTO #ExchangeRate
		SELECT
			e.ExchangeId,
			e.Rate
		FROM dbo.Lrf_f_GetExchangeRate(DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), @BaseCurrency, '') AS e
		WHERE EXISTS (SELECT 1 FROM #Data WHERE Currency = e.ExchangeId)
	END

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	SELECT A.*
	FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.Status ASC, b.TransId ASC) AS RowNum,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
				b.CustId,
				b.SportType,
				b.Username,
				b.BetType,
				b.TransId,
				b.MatchCode,
				b.Race,
				b.EventDate,
				b.LeagueId,
				b.HomeId,
				b.AwayId,
				b.Hdp1,
				b.Hdp2,
				b.Odds,
				b.Status,
				b.SettlementStatus,
				b.Stake * ISNULL(e.Rate, 1) AS Stake,
				b.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
				b.TransDate,
				b.BetTeam,
				b.LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Discount,
				b.Ip,
				b.IsNeutral,
				b.OddsType,
				b.BetId,
				b.Currency,
				b.RefNo,
				b.ShowTime,
				b.BetCheck,
				b.BetdaqId,
				b.ExtraInfo,
				b.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
				b.OriginalBetType,
				b.WalletType,
				b.RefCode
			FROM #Data AS b
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.CustId
				LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = b.currency
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #Data
	DROP TABLE #ExchangeRate
END
GO
