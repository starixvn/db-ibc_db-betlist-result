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
		- 20141120@Jim: Expand data range for @transid param to covert big datatype
		- 20150128@Jim: base on GBP
		- 20150415@Jim: support betradar
		- 20151210@Kos: support PH All In One 4 new bet types 401, 402, 403, 404 (O/U bettypes)
		- 20160115@Joseph: Redefine values of parameter betfrom
		- 20160413@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160919@Kos: Add column transdesc to support PH AIO phase 2b [#Redmine: 62878]
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20170331@Kos: Support CashOut [#Redmine: 71963]
		- 20170419@Kos: Support BAIO [#Redmine: 73030]

	Parameter's Explanation:
		- @BetType:
			+ HDP: 1, 7, 1303, 17, 183, 609
			+ Others: NOT IN 1,3,7,8,17,18,178,183,1303,1306, 401, 402, 403, 404
			+ OU: 3, 18, 8, 178, 1306, 401, 402, 403, 404, 610, 615, 616
			+ ALL: <=19000
		- @TransId: lastest transid 
		- @LimitRowCount: max record return (10,20,30)
		- @SportID = 999 -> Parlay and System Parlay
		- @LiveIndicator (0 : non live, 1 : live , 2 : mix non live & live)
		- @IncludeBetFrom: 1: show column betfrom, 0: hide
		- @BetFrom: 0: All
					1: Asia (d)
					2: New Asia (a)
					3: Euro (e) and Euro 12bet (u)
					4: WAP (m)
					5: Smartphone (s) and Smartphone - Licensee (l)
	Excecute sample :
		[Lrf_Monitor_BetlistSel_New]
			@LicenseeID = 14,
			@BetType='HDP',
			@LicenseeType='Normal',
			@Currency='1,2,3,4,5,6,7,8,9,10',
			@SpecialLevel='0,1,2,3,4,5,6,7,8,9',
			@transid=0,
			@LimitRowCount=10,
			@SportID=1,
			@LeagueID=3,
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
			ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH

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

	IF @SportID > 0 AND @SportID <> 999
	BEGIN
		SET @SQL =
			'DECLARE @match TABLE(matchid INT primary key)' + CHAR(13) +
			'INSERT INTO @match' + CHAR(13) +
			'SELECT matchid' + CHAR(13) +
			'FROM dbo.match WITH (NOLOCK)' + CHAR(13) +
			'WHERE sporttype = ' + CONVERT(VARCHAR(10), @SportId) + ' AND eventstatus = ''running''' + CHAR(13) +
			CASE 
				WHEN @LeagueId > 0 THEN 'AND leagueid = ' + CONVERT(VARCHAR(10), @LeagueId)
				ELSE ''
			END + CHAR(13) +
			CASE
				WHEN @MatchId > 0 THEN 'AND matchid = ' + CONVERT(VARCHAR(10), @MatchId)
				ELSE ''
			END + CHAR(13) +
			'UNION ALL' + CHAR(13) +
			'SELECT o.orid' + CHAR(13) +
			'FROM (SELECT orid, leagueid FROM dbo.outright WITH (NOLOCK) WHERE oddsstatus = ''running'') AS o ' + CHAR(13) +
				'CROSS APPLY (SELECT l.leagueid FROM dbo.league l WITH (NOLOCK) WHERE o.leagueid = l.leagueid AND l.sporttype = ' + CONVERT(VARCHAR(10),@SportID) + ') AS l2' + CHAR(13) +
			'WHERE (1=1)' + CHAR(13) +
			CASE
				WHEN @LeagueID > 0 THEN 'AND o.leagueid = ' + CONVERT(VARCHAR(10), @LeagueId)
				ELSE ''
			END + CHAR(13) +
			CASE
				WHEN @Matchid > 0 THEN 'AND o.orid = ' + CONVERT(VARCHAR(10), @MatchId)
				ELSE ''
			END + CHAR(13)
	END

	SELECT @SQL = @SQL + 'SELECT TOP (' + CONVERT(VARCHAR(10), @LimitRowCount) + ')' + CHAR(13) +
			'0 AS sporttype,' + CHAR(13) +
			'b.matchid,' + CHAR(13) +
			'0 AS leagueid,' + CHAR(13) +
			'b.Username,' + CHAR(13) +
			'SUBSTRING(b.username2, CHARINDEX(''$'', b.username2) + 1,LEN(b.username2) - CHARINDEX(''$'',b.username2)) AS nickname,'+ CHAR(13) +
			'b.bettype,' + CHAR(13) +
			'b.transid,' + CHAR(13) +
			'b.refno,' + CHAR(13) +
			'b.transdate,' + CHAR(13) +
			''''' AS matchcode,' + CHAR(13) +
			'0 AS homeid,' + CHAR(13) +
			'0 AS awayid,' + CHAR(13) +
			''''' AS race,' + CHAR(13) +
			'b.betid,' + CHAR(13) +
			'b.livehomescore,' + CHAR(13) +
			'b.liveawayscore,' + CHAR(13) +
			'b.liveindicator,' + CHAR(13) +
			'b.hdp1,' + CHAR(13) +
			'b.hdp2,' + CHAR(13) +
			'b.odds,' + CHAR(13) +
			CASE
				WHEN @BaseCurrency = 'USD' THEN 'b.actual_stake * ex.USD actual_stakeUSD,'
				WHEN @BaseCurrency = 'EUR' THEN 'b.actual_stake * ex.EUR actual_stakeEUR,'
				WHEN @BaseCurrency = 'GBP' THEN 'b.actual_stake * ex.GBP actual_stakeGBP,'
				ELSE 'b.actual_stake AS Actual_Stake' + @BaseCurrency + ','
			END + CHAR(13) +
			CASE
				WHEN @BaseCurrency = 'USD' THEN 'b.stake * ex.USD StakeUSD,'
				WHEN @BaseCurrency = 'EUR' THEN 'b.stake * ex.EUR StakeEUR,'
				WHEN @BaseCurrency = 'GBP' THEN 'b.stake * ex.GBP StakeGBP,'
				ELSE 'b.stake AS Stake' + @BaseCurrency + ','
			END + CHAR(13) +
			CASE WHEN @includebetfrom = 1 THEN 'betfrom,'
				ELSE ''
			END + CHAR(13) +
			'''running'' AS status,' + CHAR(13) +
			'b.betteam,' + CHAR(13) +
			'CONVERT(BIT,0) AS isNeutral,' + CHAR(13) +
			'b.OddsType,' + CHAR(13) +
			'b.currency AS currencyid,' + CHAR(13) +
			''''' AS currencyname,' + CHAR(13) +
			'b.SpecialLevel,' + CHAR(13) +
			'ISNULL(b.betcheck, '''') AS BetCheck,' + CHAR(13) +
			'ISNULL(b.transdesc, '''') AS TransDesc,' + CHAR(13) +
			'ISNULL(b.betdaqid, -1) AS BetdaqId,' + CHAR(13) +
			'ISNULL(b.ExtraInfo, '''') AS ExtraInfo,' + CHAR(13) +
			'CASE
				WHEN b.ExtraInfo LIKE ''%p25%'' THEN
					ISNULL(CAST((''<xml>'' + b.ExtraInfo + ''</xml>'') AS XML).value(''data(/xml/p25/@s)[1]'',''MONEY''), 0)
				ELSE 0
			END ' + CASE
						WHEN @BaseCurrency = 'USD' THEN '* ex.USD AS OriginalStakeUSD'
						WHEN @BaseCurrency = 'EUR' THEN '* ex.EUR AS OriginalStakeEUR'
						WHEN @BaseCurrency = 'GBP' THEN '* ex.GBP AS OriginalStakeGBP'
						ELSE 'AS OriginalStake' + @BaseCurrency
					END + ',' + CHAR(13) +
			'CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType
		FROM dbo.bettrans_lrf_betRunning b WITH (NOLOCK) ' + CHAR(13) +
			'INNER JOIN Lrf_f_GetExchangeDaily(CONVERT(VARCHAR(10), GETDATE(), 111),CONVERT(VARCHAR(10), GETDATE(), 111)) ex ON ex.exchangeid = b.currency ' + CHAR(13) +
			'INNER JOIN #TempAg a WITH (NOLOCK) ON b.Recommend = a.CustId AND b.Currency = a.Currency'+ CHAR(13) +
			CASE
				WHEN @SportID > 0 AND @Sportid <> 999 THEN 'INNER JOIN @Match m ON b.matchid = m.matchid '
				ELSE ' '
			END + CHAR(13) +
		'WHERE Transid >' + CONVERT(VARCHAR(20), @transid) + '  ' + CHAR(13) +
			'AND Statusid = 0' + CHAR(13) +
			CASE
				WHEN @betfrom = 1 THEN 'AND betfrom=''d'''
				WHEN @betfrom = 2 THEN 'AND betfrom=''a'''
				WHEN @betfrom = 3 THEN 'AND betfrom IN (''e'',''u'')'
				WHEN @betfrom = 4 THEN 'AND betfrom=''m'''
				WHEN @betfrom = 5 THEN 'AND betfrom IN (''s'',''l'')'
				ELSE ''
			END + CHAR(13) +
			CASE
				WHEN @BaseCurrency = 'USD' THEN
					CASE
						WHEN @MinStake = 0 AND @MaxStake > 0 THEN 'AND b.stake * ex.USD <= ' + CONVERT(VARCHAR(20), @MaxStake)
						WHEN @MinStake > 0 AND @MaxStake = 0 THEN 'AND b.stake * ex.USD >= ' + CONVERT(VARCHAR(20), @MinStake)
						WHEN @MinStake > 0 AND @MaxStake > 0 THEN 'AND b.stake * ex.USD BETWEEN ' + CONVERT(VARCHAR(20), @MinStake) +' AND ' + CONVERT(VARCHAR(20),@MaxStake)
						ELSE ' '
					END
				WHEN @BaseCurrency = 'EUR' THEN 
					CASE
						WHEN @MinStake = 0 AND @MaxStake > 0 THEN 'AND b.stake * ex.EUR <= ' + CONVERT(VARCHAR(20), @MaxStake)
						WHEN @MinStake > 0 AND @MaxStake = 0 THEN 'AND b.stake * ex.EUR >= ' + CONVERT(VARCHAR(20), @MinStake)
						WHEN @MinStake > 0 AND @MaxStake > 0 THEN 'AND b.stake * ex.EUR BETWEEN ' + CONVERT(VARCHAR(20), @MinStake) +' AND ' + CONVERT(VARCHAR(20), @MaxStake)
						ELSE ' '
					END
				WHEN @BaseCurrency = 'GBP' THEN 
					CASE
						WHEN @MinStake = 0 AND @MaxStake > 0 THEN 'AND b.stake * ex.GBP <= ' + CONVERT(VARCHAR(20), @MaxStake)
						WHEN @MinStake > 0 AND @MaxStake = 0 THEN 'AND b.stake * ex.GBP >= ' + CONVERT(VARCHAR(20), @MinStake)
						WHEN @MinStake > 0 AND @MaxStake > 0 THEN 'AND b.stake * ex.GBP BETWEEN ' + CONVERT(varchar(20), @MinStake) +' AND ' + CONVERT(varchar(20), @MaxStake)
						ELSE ' '
					END
				ELSE
					CASE
						WHEN @MinStake = 0 AND @MaxStake > 0 THEN 'AND b.stake <= ' + CONVERT(VARCHAR(20), @MaxStake)
						WHEN @MinStake > 0 AND @MaxStake = 0 THEN 'AND b.stake >= ' + CONVERT(VARCHAR(20), @MinStake)
						WHEN @MinStake > 0 AND @MaxStake > 0 THEN 'AND b.stake BETWEEN ' + CONVERT(VARCHAR(20), @MinStake) +' AND ' + CONVERT(VARCHAR(20), @MaxStake)
						ELSE ' '
				END
			END + CHAR(13) +
			CASE WHEN @Currency <> 'ALL' THEN 'AND b.currency IN (' + @Currency + ') ' ELSE ' ' END + CHAR(13) +
			CASE WHEN @SpecialLevel <> 'ALL' THEN 'AND SpecialLevel IN (' + @SpecialLevel + ')' ELSE ' ' END + CHAR(13) +
			CASE
				WHEN @SportID > 0 AND @SportID < 999 AND @LiveIndicator IN (0,1) THEN 'AND Liveindicator = '+CONVERT(VARCHAR(10),@LiveIndicator)
				WHEN @SportID > 0 AND @SportID < 999 AND @LiveIndicator = 2 THEN 'AND b.bettype = 9 AND b.Livehomescore=' + CONVERT(VARCHAR(10),@LiveIndicator)
				WHEN @SportID > 0 AND @Sportid <> 999 AND @LiveIndicator = 3 THEN'AND ( b.bettype < 31 OR b.bettype BETWEEN 121 AND 999 OR (b.Bettype BETWEEN 1301 AND 1399) )'
				ELSE ' '
			END + CHAR(13) +
			CASE
				WHEN @SportID = 0 THEN
					CASE
						WHEN @LiveIndicator = 3 THEN 'AND ( b.bettype < 31 OR b.bettype BETWEEN 121 AND 999 OR (b.Bettype BETWEEN 1301 AND 1399))' 
						WHEN @LiveIndicator = 2 THEN 'AND b.bettype = 9 AND b.Livehomescore=' + CONVERT(VARCHAR(10),@LiveIndicator) + ' '
						WHEN @LiveIndicator IN (0,1) THEN 
						'AND (
							(Liveindicator=' + CONVERT(VARCHAR(10), @LiveIndicator) +
								' AND ((b.bettype < 31 AND b.bettype NOT IN (9,29))
									OR b.bettype BETWEEN 121 AND 999
									OR b.Bettype BETWEEN 1301 AND 1399)) ' +
							'OR (b.bettype IN (9,29) AND b.Livehomescore=' + CONVERT(VARCHAR(10),@LiveIndicator) + ')) '
						ELSE ' '
					END
				ELSE ' '
			END + CHAR(13) +
			CASE
				WHEN @BetType = 'HDP' AND @SportID <> 999 THEN 'AND b.bettype IN (1, 7, 1303, 17, 183, 609)'
				WHEN @BetType = 'OU' AND @SportID <> 999 THEN ' AND b.bettype IN (3, 18, 8, 178, 1306, 401, 402, 403, 404, 610, 615, 616)'
				WHEN @BetType = 'Others' AND @SportID <> 999 THEN ' AND b.bettype NOT IN (1, 3, 7, 8, 17, 18, 178, 183, 1303, 1306, 401, 402, 403, 404, 609, 610, 615, 616)'
				ELSE ' '
			END + CHAR(13)+
			CASE @SportID
				WHEN 999 THEN 
					CASE @LiveIndicator 
						WHEN 3 THEN 'AND b.bettype IN (9,29) '
						WHEN 2 THEN 'AND b.bettype = 9 AND b.Livehomescore = ' + CONVERT(VARCHAR(10), @LiveIndicator) + ' '
						ELSE 'AND b.bettype IN (9, 29) AND b.Livehomescore = ' + CONVERT(VARCHAR(10), @LiveIndicator) + ' '
					END
				ELSE ''
			END + CHAR(13) +
		'ORDER BY transid DESC'

	IF @Debug = 1
		PRINT @sql
	ELSE
		EXEC(@sql)

	DROP TABLE #TempAg
END




GO
GRANT EXECUTE ON [dbo].[Lrf_Monitor_BetlistSel_New] TO [bodbLicenseeNet]  
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Monitor_BetlistSel_New] TO [vnteam]  