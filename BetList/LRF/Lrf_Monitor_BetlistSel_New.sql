USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_Monitor_BetlistSel_New]
	@AgentList		VARCHAR(MAX),
	@BetType		VARCHAR(50)		= NULL,
	@Currency		VARCHAR(200)	= NULL,
	@SpecialLevel	VARCHAR(200)	= NULL,
	@TransId		BIGINT			= 0,
	@LimitRowCount	INT				= 10,
	@SportId		INT				= 0,
	@LeagueId		INT				= 0,
	@MatchId		INT				= 0,
	@MinStake		MONEY			= 0,
	@MaxStake		MONEY			= 0,
	@LiveIndicator	INT				= 0,
	@IncludeBetFrom	BIT				= 1,
	@BetFrom		TINYINT			= 0,
	@BaseCurrency	VARCHAR(10)		='USD',
	@Debug			BIT				= 0
AS

/*
	Created: Scott@20130418
	Task: LRF Monitor lastest bets list(all bettypes and all sports) with filter by League and Sport
	DB: DBEXT.bodb02
	Original: [Lrf_Monitor_BetlistSel]
	Revision:
		- 20130618@Jim: Restrict permission of Licensee Users by currency
		- 20130806@Jim: Add betting platform to Last bets monitoring
		- 20140620@Florent: Offer Sporting Solution (36 new bettypes)
		- 20141021@Florent: Apply for the change in Sporting Solution structure (#24478)
		- 20141120@Jim: Expand data range for @TransId param to covert big datatype
		- 20150128@Jim: base on GBP
		- 20150415@Jim: Support betradar
		- 20151210@Kos: Support PH All In One 4 new bet types 401, 402, 403, 404 (O/U bettypes)
		- 20160115@Joseph: Redefine values of parameter betfrom
		- 20160413@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160919@Kos: Add column transdesc to support PH AIO phase 2b [#Redmine: 62878]
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20170331@Kos: Support CashOut [#Redmine: 71963]
		- 20170419@Kos: Support BAIO [#Redmine: 73030]
		- 20170803@Kos: Support more betfrom value [#Redmine: 80687]
		- 20170920@Kos: Support new bet types 461-464 [#Redmine: 83260]
		- 20171020@Kos: Support new platform New Asia [#Redmine: 85203]
		- 20171031@Kos: Support Licensee Bonus System [#Redmine: 72792]

	Parameter's Explanation:
		- @BetType:
			+ HDP: 1, 7, 1303, 17, 183, 609
			+ OU: 3, 18, 8, 178, 1306, 401, 402, 403, 404, 461, 462, 463, 464, 610, 615, 616
			+ Others: NOT IN 1, 3, 7, 8, 17, 18, 178, 183, 1303, 1306, 401, 402, 403, 404, 461, 462, 463, 464
			+ ALL: <= 19000
		- @TransId: lastest transid
		- @LimitRowCount: max record return (10,20,30)
		- @SportId = 999 -> Parlay and System Parlay
		- @LiveIndicator (0 : non live, 1 : live , 2 : mix non live & live)
		- @IncludeBetFrom: 1: show column betfrom, 0: hide
		- @BetFrom: 0 - All: All
					1 - Asia: d (mobile), g (MG Download only)
					2 - China: a (dep-Singbet), z (dep2-SingBet)
					3 - Euro: e (Europe), u (dep-Euro), y (dep2-Euro)
					4 - WAP: m (dep-wap)
					5 - Smart Site: s (smartphone), l (dep-smart)
					6 - Tablet: r (dep2-tablet)
					7 - New Asia: x (dep2-Asia)
	Excecute sample :
		[Lrf_Monitor_BetlistSel_New]
			@LicenseeID = 14,
			@BetType='HDP',
			@LicenseeType='Normal',
			@Currency='1,2,3,4,5,6,7,8,9,10',
			@SpecialLevel='0,1,2,3,4,5,6,7,8,9',
			@TransId=0,
			@LimitRowCount=10,
			@SportId=1,
			@LeagueId=3,
			@Matchid=3874470,
			@MinStake=100,
			@LiveIndicator=0
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TempAg (CustId INT, Currency INT)

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
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH

	CREATE TABLE #Data (
		SportType		INT,
		MatchId			INT,
		LeagueId		INT,
		Username		NVARCHAR(50),
		Nickname		NVARCHAR(50),
		BetType			SMALLINT,
		TransId			BIGINT,
		RefNo			BIGINT,
		TransDate		DATETIME,
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Race			VARCHAR(50),
		BetId			BIGINT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Actual_Stake	MONEY,
		Stake			MONEY,
		BetFrom			NVARCHAR(1),
		Status			NVARCHAR(10),
		BetTeam			NVARCHAR(10),
		IsNeutral		BIT,
		OddsType		TINYINT,
		CurrencyId		SMALLINT,
		CurrencyName	NVARCHAR(50),
		SpecialLevel	INT,
		BetCheck		NVARCHAR(100),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		WalletType		TINYINT,
		RefCode			BIGINT
	)

	DECLARE @SQL VARCHAR(8000)

	SELECT @SQL = ''

	IF @Currency IS NULL OR @Currency = ''
		SET @Currency = 'ALL'

	IF @SpecialLevel IS NULL OR @SpecialLevel = ''
		SET @SpecialLevel = 'ALL'

	IF @MinStake IS NULL
		SET @MinStake = 0

	IF @MaxStake IS NULL
		SET @MaxStake = 0

	-- Check if @TransId and @TransId + 1 is combo ticket then reset @TransId
	DECLARE @RefCode	BIGINT

	SELECT @RefCode = RefCode
	FROM bettrans_lrf_betRunning WITH (NOLOCK)
	WHERE transid = @TransId

	IF @RefCode IS NOT NULL AND @RefCode > 0
	BEGIN
		IF EXISTS (	SELECT 1 FROM bettrans_lrf_betRunning WITH (NOLOCK)
					WHERE transid = @TransId + 1 AND RefCode = @RefCode )
		BEGIN
			SET @TransId = @TransId + 1
		END
	END

	IF @SportId > 0 AND @SportId <> 999
	BEGIN
		SET @SQL =
			'DECLARE @match TABLE(matchid INT primary key)

			INSERT INTO @match
			SELECT matchid
			FROM dbo.match WITH (NOLOCK)
			WHERE sporttype = ' + CONVERT(VARCHAR(10), @SportId) + ' AND eventstatus = ''running''' + CHAR(13) +
			CASE
				WHEN @LeagueId > 0 THEN 'AND leagueid = ' + CONVERT(VARCHAR(10), @LeagueId) + CHAR(13)
				ELSE ''
			END +
			CASE
				WHEN @MatchId > 0 THEN 'AND matchid = ' + CONVERT(VARCHAR(10), @MatchId) + CHAR(13)
				ELSE ''
			END +
			'UNION ALL
			SELECT o.orid
			FROM (SELECT orid, leagueid FROM dbo.outright WITH (NOLOCK) WHERE oddsstatus = ''running'') AS o
				CROSS APPLY (SELECT l.leagueid FROM dbo.league l WITH (NOLOCK) WHERE o.leagueid = l.leagueid AND l.sporttype = ' + CONVERT(VARCHAR(10),@SportId) + ') AS l2
			WHERE (1=1)' + CHAR(13) +
			CASE
				WHEN @LeagueId > 0 THEN 'AND o.leagueid = ' + CONVERT(VARCHAR(10), @LeagueId) + CHAR(13)
				ELSE ''
			END +
			CASE
				WHEN @MatchId > 0 THEN 'AND o.orid = ' + CONVERT(VARCHAR(10), @MatchId) + CHAR(13)
				ELSE ''
			END + CHAR(13)
	END

	SELECT @SQL = @SQL + 'INSERT INTO #Data
		SELECT
			0 AS SportType,
			b.matchid,
			0 AS LeagueId,
			b.Username,
			SUBSTRING(b.username2, CHARINDEX(''$'', b.username2) + 1, LEN(b.username2) - CHARINDEX(''$'', b.username2)) AS Nickname,
			b.bettype,
			b.transid,
			b.refno,
			b.transdate,
			'''' AS MatchCode,
			0 AS HomeId,
			0 AS AwayId,
			'''' AS Race,
			b.betid,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.actual_stake,
			b.stake,' + CHAR(13) +
			CASE WHEN @IncludeBetFrom = 1 THEN 'b.betfrom,'
				ELSE ''
			END + CHAR(13) +
			'''running'' AS Status,
			b.betteam,
			CONVERT(BIT,0) AS IsNeutral,
			b.OddsType,
			b.currency AS CurrencyId,
			'''' AS CurrencyName,
			b.SpecialLevel,
			ISNULL(b.betcheck, '''') AS BetCheck,
			ISNULL(b.transdesc, '''') AS TransDesc,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '''') AS ExtraInfo,
			CASE
				WHEN b.ExtraInfo LIKE ''%p25%'' THEN
					ISNULL(CAST((''<xml>'' + b.ExtraInfo + ''</xml>'') AS XML).value(''data(/xml/p25/@s)[1]'',''MONEY''), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			ISNULL(b.WalletType, 0) AS WalletType,
			ISNULL(b.RefCode, 0) AS RefCode
		FROM dbo.bettrans_lrf_betRunning AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a WITH (NOLOCK) ON b.Recommend = a.CustId AND b.Currency = a.Currency' + CHAR(13) +
			CASE
				WHEN @SportId > 0 AND @SportId <> 999 THEN 'INNER JOIN @Match AS m ON b.matchid = m.matchid '
				ELSE ' '
			END + CHAR(13) +
		'WHERE b.statusID = 0
			AND b.transid > ' + CONVERT(VARCHAR(20), @TransId) + ' ' + CHAR(13) +
			CASE
				WHEN @BetFrom = 1 THEN 'AND betfrom IN (''d'', ''g'')'
				WHEN @BetFrom = 2 THEN 'AND betfrom IN (''a'', ''z'')'
				WHEN @BetFrom = 3 THEN 'AND betfrom IN (''e'', ''u'', ''y'')'
				WHEN @BetFrom = 4 THEN 'AND betfrom = ''m'''
				WHEN @BetFrom = 5 THEN 'AND betfrom IN (''s'', ''l'')'
				WHEN @BetFrom = 6 THEN 'AND betfrom = ''r'''
				WHEN @BetFrom = 7 THEN 'AND betfrom = ''x'''
				ELSE ''
			END + CHAR(13) +
			CASE
				WHEN @Currency <> 'ALL' THEN 'AND b.currency IN (' + @Currency + ') '
				ELSE ' '
			END + CHAR(13) +
			CASE
				WHEN @SpecialLevel <> 'ALL' THEN 'AND SpecialLevel IN (' + @SpecialLevel + ')'
				ELSE ' '
			END + CHAR(13) +
			CASE
				WHEN @SportId > 0 AND @SportId < 999 AND @LiveIndicator IN (0,1) THEN 'AND Liveindicator = ' + CONVERT(VARCHAR(10), @LiveIndicator)
				WHEN @SportId > 0 AND @SportId < 999 AND @LiveIndicator = 2 THEN 'AND b.bettype IN (9, 29) AND b.Livehomescore=' + CONVERT(VARCHAR(10), @LiveIndicator)
				WHEN @SportId > 0 AND @SportId <> 999 AND @LiveIndicator = 3 THEN 'AND ( b.bettype < 31 OR b.bettype BETWEEN 121 AND 999 OR (b.Bettype BETWEEN 1301 AND 1399) )'
				ELSE ' '
			END + CHAR(13) +
			CASE
				WHEN @SportId = 0 THEN
					CASE
						WHEN @LiveIndicator = 3 THEN 'AND ( b.bettype < 31 OR b.bettype BETWEEN 121 AND 999 OR (b.Bettype BETWEEN 1301 AND 1399))'
						WHEN @LiveIndicator = 2 THEN 'AND b.bettype IN (9, 29) AND b.Livehomescore=' + CONVERT(VARCHAR(10), @LiveIndicator) + ' '
						WHEN @LiveIndicator IN (0,1) THEN 
						'AND ((Liveindicator=' + CONVERT(VARCHAR(10), @LiveIndicator) +
								' AND ((b.bettype < 31 AND b.bettype NOT IN (9, 29))
									OR b.bettype BETWEEN 121 AND 999
									OR b.Bettype BETWEEN 1301 AND 1399)) ' +
							'OR (b.bettype IN (9, 29) AND b.Livehomescore=' + CONVERT(VARCHAR(10), @LiveIndicator) + ')) '
						ELSE ' '
					END
				WHEN @SportId = 999 THEN
					CASE @LiveIndicator
						WHEN 3 THEN 'AND b.bettype IN (9, 29) '
						WHEN 2 THEN 'AND b.bettype IN (9, 29) AND b.Livehomescore = ' + CONVERT(VARCHAR(10), @LiveIndicator) + ' '
						ELSE 'AND b.bettype IN (9, 29) AND b.Livehomescore = ' + CONVERT(VARCHAR(10), @LiveIndicator) + ' '
					END
				ELSE ' '
			END + CHAR(13) +
			CASE
				WHEN @BetType = 'HDP' AND @SportId <> 999 THEN 'AND b.bettype IN (1, 7, 1303, 17, 183, 609)'
				WHEN @BetType = 'OU' AND @SportId <> 999 THEN ' AND b.bettype IN (3, 18, 8, 178, 1306, 401, 402, 403, 404, 461, 462, 463, 464, 610, 615, 616)'
				WHEN @BetType = 'Others' AND @SportId <> 999 THEN ' AND b.bettype NOT IN (1, 3, 7, 8, 17, 18, 178, 183, 1303, 1306, 401, 402, 403, 404, 461, 462, 463, 464, 609, 610, 615, 616)'
				ELSE ' '
			END + CHAR(13)

	IF @Debug = 1
		PRINT @sql
	ELSE
		EXEC(@sql)

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

	SELECT *
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(CONVERT(VARCHAR(10), GETDATE(), 111),CONVERT(VARCHAR(10), GETDATE(), 111))
	WHERE exchangeid IN (SELECT DISTINCT CurrencyId FROM #Data)

	SELECT TOP(@LimitRowCount)
		b.*,
		b.Stake * e.USD AS StakeUSD,
		b.Stake * e.EUR AS StakeEUR,
		b.Stake * e.GBP AS StakeGBP,
		b.Actual_Stake * e.USD AS Actual_StakeUSD,
		b.Actual_Stake * e.EUR AS Actual_StakeEUR,
		b.Actual_Stake * e.GBP AS Actual_StakeGBP,
		b.OriginalStake * e.USD AS OriginalStakeUSD,
		b.OriginalStake * e.EUR AS OriginalStakeEUR,
		b.OriginalStake * e.GBP AS OriginalStakeGBP
	FROM #Data AS b
		INNER JOIN #TempExchange AS e ON e.exchangeid = b.CurrencyId
	WHERE (@BaseCurrency = 'USD'
			AND (@MinStake = 0 OR b.Stake * e.USD >= @MinStake)
			AND (@MaxStake = 0 OR b.Stake * e.USD <= @MaxStake))
		OR (@BaseCurrency = 'EUR'
			AND (@MinStake = 0 OR b.Stake * e.EUR >= @MinStake)
			AND (@MaxStake = 0 OR b.Stake * e.EUR <= @MaxStake))
		OR (@BaseCurrency = 'GBP'
			AND (@MinStake = 0 OR b.Stake * e.GBP >= @MinStake)
			AND (@MaxStake = 0 OR b.Stake * e.GBP <= @MaxStake))
		OR (@BaseCurrency NOT IN ('USD', 'EUR', 'GBP')
			AND (@MinStake = 0 OR b.Stake >= @MinStake)
			AND (@MaxStake = 0 OR b.Stake <= @MaxStake))
	ORDER BY b.TransId DESC

	DROP TABLE #TempAg
	DROP TABLE #Data
	DROP TABLE #TempExchange
END





GO
GRANT EXECUTE ON [dbo].[Lrf_Monitor_BetlistSel_New] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Monitor_BetlistSel_New] TO [vnteam]
GO
