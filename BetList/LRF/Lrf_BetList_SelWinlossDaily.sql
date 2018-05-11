USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelWinlossDaily]    Script Date: 10/1/2015 2:45:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinlossDaily]
	@AgentList			VARCHAR(MAX),
	@Date				SMALLDATETIME,
	@Product			VARCHAR(10)	= 'ALL',
	@Status				VARCHAR(10)	= 'won',
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@PageSize			INT			= 1000,
	@PageIndex			INT			= 1,
	@TotalRows			INT			= 0 OUTPUT,
	@SumWinLost			MONEY		= 0 OUTPUT,
	@SumLicenseeWL		MONEY		= 0 OUTPUT,
	@SumComm			MONEY		= 0 OUTPUT,
	@SumPlayerComm		MONEY		= 0 OUTPUT,
	@SumWinLostUSD		MONEY		= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY		= 0 OUTPUT,
	@SumCommUSD			MONEY		= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY		= 0 OUTPUT,
	@SumWinLostEUR		MONEY		= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY		= 0 OUTPUT,
	@SumCommEUR			MONEY		= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY		= 0 OUTPUT,
	@SumWinLostGBP		MONEY		= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY		= 0 OUTPUT,
	@SumCommGBP			MONEY		= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY		= 0 OUTPUT,
	@Sort				VARCHAR(20)	= 'Transid DESC'
AS

/*
	Created: 20111904@Henry
	Task: Betlist
	DB: DBEXT.bodb02
	Original:
	Revisions:
		- 20110523@Henry: Support Number Game
		- 20110616@Henry: Suport filter BA tickets
		- 20110712@Henry: Output Licensee WL + remove BA filter
		- 20110729@Henry: offer 3 new bettypes for Number Game
		- 20110927@Henry: return output params instead of secondary table
		- 20111208@Jim: change condition bettype <31
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20120723@Jim: add playercomm value
		- 20120817@Jim: add Live Casino
		- 20120912@Jim: add Virtual Sport
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20121016@Henry: enhance SP
		- 20130305@Jim: change input param @winlostdate by @date
		- 20130320@Jim: fix bug wrong Total Rows's value
		- 20130328@Scott: Support RNG Casino and Bingo
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20130619@Jim: fix bug missing RNG Casino data
		- 20130716@Jim: update matchid for RNG Casino and Bingo
		- 20131007@Jim: Enhance the usability of Daily Bet List report and offer Virtual Horse Racing & Virtual Tennis
		- 20131108@Don: Improve performance temporarily
		- 20131112@Victor: Enhance performance
		- 20131115@Jim: correct showtime value in Live Casino and Horse Racing Product
		- 20140403@Hannah: offer Keno
		- 20140421@Hannah: fix bug, add sporttype for Keno
		- 20140428@Hannah: Sort betlist
		- 20140520@Hannah: Fix bug Sort betlist
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20140717@Hannah: HotFix for Exporting excel file
		- 20140718@Jim: fix bug 'wrong to get licensee winloss/comm for Horse Racing' (#19165)
		- 20140718@Jim: fix bug 'Win loss and Licensee WL showed on web are incorrect when product is BA' (#19261)
		- 20141111@Jim: use f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150114@Winnie: remove hardcode bettype, use spottype bettype matrix
		- 20150128@Winnie: Add base currency GBP
		- 20150410@Jim: support betradar and apply report-bettype matrix
		- 20150604@Edward: Support Microgaming
		- 20150608@Edward: Exclude 3 transactions SOLD/BOUGHT/BetTrade Commission of BetTrade
		- 20150623@Edward: Fix bug Missing Sporttype for Microgaming tickets (#38450)
		- 20150916@Kos: Don't support Microgaming RNG Casino
		- 20150921@Kos: Don't support Microgaming
		- 20151014@Kos: Increase data length of @sql to 3000
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151225@Kos: Don't support RNG Casino [Redmine: #48958]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160714@Kos: Remove Bingo and change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20161005@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170301@Kos: Support sub licensees [#Redmine: 71679]
		- 20170303@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170628@Kos: Hotfix - CashOut Details link in Racing tickets [#Redmine: 79076]
		- 20170721@Kos: Support Keno Lottery [#Redmine: 79997]
		- 20170608@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180305@Kos: Don't support Live Casino anymore [#Redmine: 85965]
		- 20180320@Kos: Increase TransDesc column length [#Redmine: 92433]
		- 20180322@Kos: Support Fast Market 2 [#Redmine: 90879]
		- 20180510@Kos: Support Keno 6 new Mini Games [#Redmine: 94829]

	Param's Explanation:
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

	-- to Deal With Parameter Sniffing
	DECLARE
		@wldate			SMALLDATETIME,
		@MoveBetsDay_	SMALLDATETIME,
		@BalanceUpDay_	SMALLDATETIME
	SELECT
		@wldate			= @date,
		@MoveBetsDay_	= @MoveBetsDay,
		@BalanceUpDay_	= @BalanceUpDay

	CREATE TABLE #Data (
		SportType			INT,
		Username			NVARCHAR(50),
		NickName			NVARCHAR(50),
		BetType				INT,
		LeagueId			INT,
		TransId				BIGINT,
		MatchCode			VARCHAR(50),
		Race				NVARCHAR(20),
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		MOdds				MONEY,
		Status				NVARCHAR(50),
		Stake				MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		TransDate			DATETIME,
		WinLostDate			DATETIME,
		BetTeam				VARCHAR(300),
		LiveIndicator		INT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		MatchId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		OddsType			INT,
		BetId				BIGINT,
		Currency			SMALLINT,
		RefNo				BIGINT,
		CustId				INT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(100),
		TransDesc			NVARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		WalletType			TINYINT,
		RefCode				BIGINT,
		OddsSpread			MONEY,
		StakeUSD			MONEY,
		WinLostUSD			MONEY,
		LicenseeWLUSD		MONEY,
		CommUSD				MONEY,
		PlayerCommUSD		MONEY,
		OriginalStakeUSD	MONEY,
		StakeEUR			MONEY,
		WinLostEUR			MONEY,
		LicenseeWLEUR		MONEY,
		CommEUR				MONEY,
		PlayerCommEUR		MONEY,
		OriginalStakeEUR	MONEY,
		StakeGBP			MONEY,
		WinLostGBP			MONEY,
		LicenseeWLGBP		MONEY,
		CommGBP				MONEY,
		PlayerCommGBP		MONEY,
		OriginalStakeGBP	MONEY
	)

	DECLARE @DataSum TABLE (
		Currency		INT,
		SumWinLost		MONEY,
		SumLicenseeWL	MONEY,
		SumComm			MONEY,
		SumPlayerComm	MONEY
	)

	DECLARE @Vhr TABLE (
		OriD		INT,
		SportType	INT,
		LeagueId	INT,
		MatchCode	VARCHAR(20),
		RacerId		INT,
		BetStatus	VARCHAR(100),
		ShowTime	DATETIME,
		AwayId		INT,
		IsNeutral	INT
	)

	DECLARE @hr TABLE (
		OriD		INT,
		SportType	INT,
		LeagueId	INT,
		MatchCode	VARCHAR(20),
		Race		NVARCHAR(20),
		RacerId		INT,
		BetStatus	VARCHAR(100),
		ShowTime	DATETIME,
		AwayID		INT,
		IsNeutral	INT
	)

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1
	SELECT @RowStart = @PageSize * @PageIndex + 1
	SELECT @RowEnd = (@RowStart -1)  + @PageSize

	DECLARE @sql		NVARCHAR(4000)
	DECLARE @SortTemp	VARCHAR(250)
	DECLARE @LicenseeWL	VARCHAR(150)
	DECLARE @Winlost	VARCHAR(150)

	SELECT *
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@wldate, @wldate)

	-- Get SportBettypeMatrix
	CREATE TABLE #SportBettype (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO #SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE (@Product IN ('SB', 'BA') AND (ProductID = 1 AND Bettype NOT IN (901, 902, 903, 904)))
		OR (@Product = 'NG' AND ProductID = 3)
		OR (@Product = 'RB' AND ProductID = 2)
		OR (@Product = 'VS' AND ProductID = 5)
		OR (@Product = 'KN' AND ProductID = 8)
		OR (@Product = 'VS2' AND ProductID = 27)
		OR (@Product = 'LT' AND ProductID = 28)

	SET @LicenseeWL =
					'CASE
						WHEN b.bettype NOT IN (31,32,33) THEN - (b.winlost-b.actual_stake)
						ELSE b.awinlost 
					 END'

	SET @Winlost = '(b.winlost-b.actual_stake)'

	IF @Sort LIKE '%USD%' OR @Sort LIKE '%EUR%' OR @Sort LIKE '%GBP%'
	BEGIN
		DECLARE @CharIndex INT

		SELECT @CharIndex = CHARINDEX( ' ', @Sort, 1)
		
		IF @Sort LIKE '%Winlost%'
		BEGIN
			SELECT @SortTemp = @Winlost + '*e.' + SUBSTRING(@Sort, @CharIndex - 3,4) + SUBSTRING(@Sort, @CharIndex + 1, LEN(@Sort))
		END
		ELSE IF @Sort LIKE '%LicenseeWL%'
		BEGIN
			SELECT @SortTemp = @LicenseeWL + '*e.' + SUBSTRING(@Sort, @CharIndex - 3,4) + SUBSTRING(@Sort, @CharIndex + 1, LEN(@Sort))
		END
		ELSE
		BEGIN
			SELECT @SortTemp = SUBSTRING (@Sort, 1, @CharIndex - 4) + '*e.' + SUBSTRING(@Sort, @CharIndex - 3,4) + SUBSTRING(@Sort, @CharIndex + 1, LEN(@Sort))
		END
	END
	ELSE
	BEGIN
		SET @SortTemp = @Sort
	END

	IF @wldate > @MoveBetsDay_
	BEGIN
		IF @Product = 'VS'
		BEGIN
			INSERT INTO @Vhr
			SELECT
				o.Orid,
				r.SportType,
				r.LeagueID,
				CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
				o.RacerID,
				r.BetStatus,
				r.EventTime AS ShowTime,
				NULL AS AwayID,
				NULL AS IsNeutral
			FROM dbo.VSOutright AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventDate = @wldate
		END

		IF @Product = 'RB'
		BEGIN
			INSERT INTO @hr
			SELECT
				m.OrId,
				l.sporttype,
				m.LeagueID,
				m.MatchCode,
				m.GroupMatch,
				m.TeamID,
				0 AS BetStatus,
				'' AS ShowTime,
				NULL AS AwayID,
				CONVERT(BIT,0) AS IsNeutral
			FROM dbo.Outright AS m WITH (NOLOCK)
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			WHERE m.eventdate = @wldate
		END

		IF @Product = 'BA'
		BEGIN
			INSERT INTO @DataSum
			SELECT
				b.currency,
				SUM(ISNULL(b.winlost - b.actual_stake, 0)),
				0,
				SUM(ISNULL(b.comm, 0)),
				SUM(b.playercomm) AS SumPlayerComm
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
				INNER JOIN #SportBettype AS sbt ON sbt.Bettype = b.bettype
				INNER JOIN #TempAg AS ag ON b.recommend = ag.custid AND b.currency = ag.Currency
			WHERE
				b.winlostdate = @wldate
				AND b.bettype NOT IN (9, 29, 10)
				AND b.status = @status
				AND b.ruben = 1
				AND b.tpositiontaking = 0
			GROUP BY b.currency
		END

		IF @Product <> 'BA'
		BEGIN
			INSERT INTO @DataSum
			SELECT
				b.currency,
				SUM(ISNULL(b.winlost - b.actual_stake, 0)),
				-SUM(ISNULL(CASE WHEN b.bettype IN (31, 32, 33) THEN b.awinlost
								ELSE (b.winlost - b.actual_stake) 
							END, 0)),
				SUM(ISNULL(b.comm, 0)),
				SUM(b.playercomm) AS SumPlayerComm
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #SportBettype AS sbt ON sbt.Bettype = b.bettype
				INNER JOIN #TempAg AS ag ON b.recommend = ag.custid AND b.currency = ag.Currency
			WHERE
				b.winlostdate = @wldate
				AND b.bettype NOT IN (9, 29, 10, 2799)
				AND b.status = @status
				AND b.ruben = 1
				AND ((@Product = 'SB' AND b.tpositiontaking <> 0)
					OR @Product <> 'SB')
			GROUP BY b.currency
		END

		CREATE TABLE #BetData1 (
			OddsId				INT,
			SportType			INT,
			Username			NVARCHAR(50),
			NickName			NVARCHAR(50),
			BetType				INT,
			LeagueId			INT,
			TransId				BIGINT,
			MatchCode			VARCHAR(50),
			Race				NVARCHAR(20),
			HomeId				INT,
			AwayId				INT,
			Hdp1				SMALLMONEY,
			Hdp2				SMALLMONEY,
			Odds				MONEY,
			MOdds				MONEY,
			Status				NVARCHAR(50),
			Stake				MONEY,
			WinLost				MONEY,
			LicenseeWL			MONEY,
			Comm				MONEY,
			PlayerComm			MONEY,
			TransDate			DATETIME,
			WinLostDate			DATETIME,
			BetTeam				NVARCHAR(10),
			LiveIndicator		INT,
			LiveHomeScore		SMALLINT,
			LiveAwayScore		SMALLINT,
			MatchId				INT,
			BetStatus			NVARCHAR(50),
			IsNeutral			BIT,
			OddsType			INT,
			BetId				BIGINT,
			Currency			SMALLINT,
			RefNo				BIGINT,
			CustId				INT,
			ShowTime			NVARCHAR(50),
			BetCheck			NVARCHAR(100),
			TransDesc			NVARCHAR(1000),
			OriginalStake		MONEY,
			OriginalBetType		SMALLINT,
			BetdaqId			BIGINT,
			ExtraInfo			VARCHAR(1000),
			WalletType			TINYINT,
			RefCode				BIGINT,
			OddsSpread			MONEY,
			StakeUSD			MONEY,
			WinLostUSD			MONEY,
			LicenseeWLUSD		MONEY,
			CommUSD				MONEY,
			PlayerCommUSD		MONEY,
			OriginalStakeUSD	MONEY,
			StakeEUR			MONEY,
			WinLostEUR			MONEY,
			LicenseeWLEUR		MONEY,
			CommEUR				MONEY,
			PlayerCommEUR		MONEY,
			OriginalStakeEUR	MONEY,
			StakeGBP			MONEY,
			WinLostGBP			MONEY,
			LicenseeWLGBP		MONEY,
			CommGBP				MONEY,
			PlayerCommGBP		MONEY,
			OriginalStakeGBP	MONEY
		)

		-- Get Betdata from bettrans and filter by row number
		SET @sql = 
		'SELECT
			b.oddsid,
			CASE
				WHEN sbt.ProductID = 8 THEN 202
				WHEN sbt.ProductID = 28 THEN 220
				ELSE 0
			END AS SportType,
			b.username,
			SUBSTRING(c.username2, CHARINDEX(''$'', c.username2) + 1, LEN(c.username2) - CHARINDEX(''$'', c.username2)) AS Nickname,
			b.bettype,
			0 AS leagueID,
			b.transid,
			'''' AS matchcode,
			'''' AS Race,
			0 AS homeID,
			0 AS awayID,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			(b.winlost - b.actual_stake) AS WinLost,
			CASE
				WHEN b.bettype NOT IN (31,32,33) THEN - (b.winlost - b.actual_stake)
				ELSE awinlost
			END AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			CASE
				WHEN sbt.ProductID IN (1, 2, 3, 5, 27) THEN b.betteam
				ELSE ''''
			END AS BetTeam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid,
			'''' AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			b.custid,
			'''' AS showtime,
			CASE
				WHEN sbt.ProductID = 8 THEN ISNULL(b.comstatus, '''')
				ELSE ''''
			END AS BetCheck,
			ISNULL(b.transdesc, '''') AS transdesc,
			CASE
				WHEN sbt.ProductID = 1 AND b.ExtraInfo LIKE ''%p25%'' THEN
					ISNULL(CAST((''<xml>'' + b.ExtraInfo + ''</xml>'') AS XML).value(''data(/xml/p25/@s)[1]'',''MONEY''), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			CASE
				WHEN sbt.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			ISNULL(b.ExtraInfo, '''') AS ExtraInfo,
			ISNULL(b.WalletType, 0) AS WalletType,
			ISNULL(b.RefCode, 0) AS RefCode,
			CASE
				WHEN sbt.ProductID = 1 THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			-- USD
			b.stake * e.USD stakeUSD,'
			+ @Winlost + ' * e.USD WinlostUSD,'
			+ @LicenseeWL + ' * e.USD LicenseeWLUSD,
			b.comm * e.USD commUSD,
			b.playercomm * e.USD AS PlayerCommUSD,
			CASE
				WHEN sbt.ProductID = 1 AND b.ExtraInfo LIKE ''%p25%'' THEN
					ISNULL(CAST((''<xml>'' + b.ExtraInfo + ''</xml>'') AS XML).value(''data(/xml/p25/@s)[1]'',''MONEY''), 0)
				ELSE 0
			END * e.USD AS OriginalStakeUSD,
			-- EUR
			b.stake * e.EUR stakeEUR,'
			+ @Winlost + '* e.EUR WinlostEUR,'
			+ @LicenseeWL + '* e.EUR LicenseeWLEUR,
			b.comm * e.EUR commEUR,
			b.playercomm * e.EUR AS PlayerCommEUR,
			CASE
				WHEN sbt.ProductID = 1 AND b.ExtraInfo LIKE ''%p25%'' THEN
					ISNULL(CAST((''<xml>'' + b.ExtraInfo + ''</xml>'') AS XML).value(''data(/xml/p25/@s)[1]'',''MONEY''), 0)
				ELSE 0
			END * e.EUR AS OriginalStakeEUR,
			-- GBP
			b.stake * e.GBP AS stakeGBP,'
			+ @Winlost + '* e.GBP AS WinlostGBP,'
			+ @LicenseeWL + '* e.GBP AS LicenseeWLGBP,
			b.comm * e.GBP AS commGBP,
			b.playercomm * e.GBP AS PlayerCommGBP,
			CASE
				WHEN sbt.ProductID = 1 AND b.ExtraInfo LIKE ''%p25%'' THEN
					ISNULL(CAST((''<xml>'' + b.ExtraInfo + ''</xml>'') AS XML).value(''data(/xml/p25/@s)[1]'',''MONEY''), 0)
				ELSE 0
			END * e.GBP AS OriginalStakeGBP
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.customer AS c WITH (NOLOCK) ON b.custid = c.custid
			INNER JOIN #TempAg AS ag ON b.recommend = ag.custid AND b.currency = ag.Currency
			INNER JOIN #SportBettype AS sbt ON sbt.Bettype = b.bettype
			INNER JOIN #TempExchange e ON  e.exchangeid = b.currency' + CHAR(13) +
			CASE
				WHEN @Product = 'BA' THEN 'INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid'
				ELSE ''
			END + CHAR(13) +
		'WHERE
			b.winlostdate = ''' + CAST(@wldate AS VARCHAR(50)) + '''' + CHAR(13) +
			'AND b.status = ''' + CAST(@status AS VARCHAR(15)) + '''' + CHAR(13) +
			'AND b.bettype NOT IN (9, 29, 10, 2799)
			AND b.ruben = 1' + CHAR(13) +
			CASE
				WHEN @Product = 'SB' THEN 'AND b.tpositiontaking <> 0'
				ELSE ''
			END + CHAR(13)

		INSERT INTO #BetData1 (
			Oddsid,
			Sporttype,
			Username,
			NickName,
			Bettype,
			LeagueID,
			Transid,
			Matchcode,
			Race,
			HomeID,
			AwayID,
			hdp1,
			hdp2,
			odds,
			modds,
			status,
			stake,
			Winlost,
			LicenseeWL,
			comm,
			PlayerComm,
			transdate,
			Winlostdate,
			betteam,
			liveindicator,
			livehomescore,
			liveawayscore,
			MatchID,
			Betstatus,
			IsNeutral,
			oddstype,
			betid,
			currency,
			RefNO,
			CustID,
			showtime,
			betcheck,
			transdesc,
			OriginalStake,
			OriginalBetType,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			OddsSpread,
			stakeUSD,
			WinlostUSD,
			LicenseeWLUSD,
			commUSD,
			PlayerCommUSD,
			OriginalStakeUSD,
			stakeEUR,
			WinlostEUR,
			LicenseeWLEUR,
			commEUR,
			PlayerCommEUR,
			OriginalStakeEUR,
			stakeGBP,
			WinlostGBP,
			LicenseeWLGBP,
			commGBP,
			PlayerCommGBP,
			OriginalStakeGBP)
		EXEC (@sql)

		-- Update LicenseeWL with LicenseeBATransaction table
		UPDATE b
		SET LicenseeWL = 0,
			LicenseeWLUSD = 0,
			LicenseeWLEUR = 0,
			LicenseeWLGBP = 0
		FROM #BetData1 AS b
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid

		-- Update data with match table
		UPDATE b
		SET sporttype = m.sporttype,
			leagueID = m.leagueid,
			matchcode = m.matchcode,
			homeID = m.homeid,
			awayID = m.awayid,
			betstatus = m.betstatus,
			IsNeutral = m.IsNeutral,
			showtime = CASE
							WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime, '')
							WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
							ELSE ''
						END
		FROM #BetData1 AS b
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN #SportBettype AS s WITH (NOLOCK) ON b.BetType = s.Bettype
		WHERE s.EventType = 1

		-- Update data with @vhr table
		UPDATE b
		SET sporttype = v.sporttype,
			leagueID = v.leagueid,
			matchcode = v.matchcode,
			homeID = v.RacerID,
			awayID = v.AwayID,
			betstatus = v.BetStatus,
			showtime = v.showtime
		FROM #BetData1 AS b
			INNER JOIN @vhr AS v ON b.oddsid = v.OrID
		WHERE b.bettype IN (1231, 1232, 1233, 1237, 1238)

		-- Update data with @hr table
		UPDATE b
		SET sporttype = r.sporttype,
			leagueID = r.leagueid,
			matchcode = r.matchcode,
			homeID = r.RacerID,
			awayID = r.AwayID,
			betstatus = r.BetStatus,
			Race = r.Race
		FROM #BetData1 AS b
			INNER JOIN @hr AS r ON b.oddsid = r.OrID
		WHERE b.bettype IN (31, 32, 33)

		-- Insert and drop temp table
		INSERT INTO #Data
		SELECT
			sporttype,
			username,
			nickname,
			bettype,
			leagueID,
			transid,
			matchcode,
			Race,
			homeID,
			awayID,
			hdp1,
			hdp2,
			odds,
			modds,
			status,
			stake,
			winlost,
			LicenseeWL,
			comm,
			PlayerComm,
			transdate,
			winlostdate,
			betteam,
			liveindicator,
			livehomescore,
			liveawayscore,
			matchid,
			betstatus,
			IsNeutral,
			OddsType,
			betid,
			currency,
			refno,
			custid,
			showtime,
			betcheck,
			transdesc,
			OriginalStake,
			OriginalBetType,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			OddsSpread,
			stakeUSD,
			WinlostUSD,
			LicenseeWLUSD,
			commUSD,
			PlayerCommUSD,
			OriginalStakeUSD,
			stakeEUR,
			WinlostEUR,
			LicenseeWLEUR,
			commEUR,
			PlayerCommEUR,
			OriginalStakeEUR,
			stakeGBP,
			WinlostGBP,
			LicenseeWLGBP,
			commGBP,
			PlayerCommGBP,
			OriginalStakeGBP
		FROM #BetData1

		DROP TABLE #BetData1
	END

	IF @wldate <= @MoveBetsDay_ AND @wldate >= @BalanceUpDay_
	BEGIN
		IF @Product = 'VS'
		BEGIN
			INSERT INTO @Vhr
			SELECT
				o.OriD
				,r.Sporttype
				,r.LeagueID
				,CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode
				,o.RacerID
				,r.BetStatus
				,r.EventTime AS ShowTime
				,NULL AS AwayID
				,NULL AS IsNeutral
			FROM dbo.VSOutright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventDate = @wldate
		END

		IF @Product = 'RB'
		BEGIN
			INSERT INTO @hr
			SELECT
				m.OrId,
				l.sporttype,
				m.LeagueID,
				m.MatchCode,
				m.GroupMatch,
				m.TeamID,
				0 BetStatus,
				'' ShowTime,
				NULL AS AwayID,
				CONVERT(BIT,0) AS IsNeutral
			FROM dbo.Outright14 AS m WITH (NOLOCK) 
				 INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			WHERE m.eventdate = @wldate
		END

		IF @Product = 'BA'
		BEGIN
			INSERT INTO @DataSum
			SELECT
				b.currency,
				SUM(ISNULL(b.winlost - b.actual_stake, 0)),
				0,
				SUM(ISNULL(b.comm, 0)),
				SUM(b.playercomm) AS SumPlayerComm
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN #SportBettype AS sbt ON sbt.Bettype = b.bettype
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction AS ba WITH (NOLOCK) ON b.transid = BA.transid
				INNER JOIN #TempAg AS ag ON b.recommend = ag.custid AND b.currency = ag.Currency
			WHERE
				b.winlostdate = @wldate
				AND b.bettype NOT IN (9, 29, 10)
				AND b.status = @status
			GROUP BY b.currency
		END

		IF @Product <> 'BA'
		BEGIN
			INSERT INTO @DataSum
			SELECT
				b.currency,
				SUM(ISNULL(b.winlost - b.actual_stake, 0)),
				-SUM(ISNULL(CASE WHEN b.bettype IN (31,32,33) THEN b.awinlost ELSE (b.winlost - b.actual_stake) END, 0)),
				SUM(ISNULL(b.comm, 0)),
				SUM(b.playercomm) AS SumPlayerComm
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN #SportBettype AS sbt ON sbt.Bettype = b.bettype
				INNER JOIN #TempAg AS ag ON b.recommend = ag.custid AND b.currency = ag.Currency
			WHERE
				b.winlostdate = @wldate
				AND b.bettype NOT IN (9, 29, 10, 2799)
				AND b.status = @status
				AND ((@Product = 'SB' AND b.tpositiontaking <> 0)
					OR (@Product <> 'SB'))
			GROUP BY b.currency
		END

		CREATE TABLE #BetData14 (
			OddsId				INT,
			SportType			INT,
			Username			NVARCHAR(50),
			NickName			NVARCHAR(50),
			BetType				INT,
			LeagueId			INT,
			TransId				BIGINT,
			MatchCode			VARCHAR(50),
			Race				NVARCHAR(20),
			HomeId				INT,
			AwayId				INT,
			Hdp1				SMALLMONEY,
			Hdp2				SMALLMONEY,
			Odds				MONEY,
			MOdds				MONEY,
			Status				NVARCHAR(50),
			Stake				MONEY,
			WinLost				MONEY,
			LicenseeWL			MONEY,
			Comm				MONEY,
			PlayerComm			MONEY,
			TransDate			DATETIME,
			WinLostDate			DATETIME,
			BetTeam				NVARCHAR(10),
			LiveIndicator		INT,
			LiveHomeScore		SMALLINT,
			LiveAwayScore		SMALLINT,
			MatchId				INT,
			BetStatus			NVARCHAR(50),
			IsNeutral			BIT,
			OddsType			INT,
			BetId				BIGINT,
			Currency			SMALLINT,
			RefNo				BIGINT,
			CustId				INT,
			ShowTime			NVARCHAR(50),
			BetCheck			NVARCHAR(100),
			TransDesc			NVARCHAR(1000),
			OriginalStake		MONEY,
			OriginalBetType		SMALLINT,
			BetdaqId			BIGINT,
			ExtraInfo			VARCHAR(1000),
			WalletType			TINYINT,
			RefCode				BIGINT,
			OddsSpread			MONEY,
			StakeUSD			MONEY,
			WinLostUSD			MONEY,
			LicenseeWLUSD		MONEY,
			CommUSD				MONEY,
			PlayerCommUSD		MONEY,
			OriginalStakeUSD	MONEY,
			StakeEUR			MONEY,
			WinLostEUR			MONEY,
			LicenseeWLEUR		MONEY,
			CommEUR				MONEY,
			PlayerCommEUR		MONEY,
			OriginalStakeEUR	MONEY,
			StakeGBP			MONEY,
			WinLostGBP			MONEY,
			LicenseeWLGBP		MONEY,
			CommGBP				MONEY,
			PlayerCommGBP		MONEY,
			OriginalStakeGBP	MONEY
		)

		-- Get Betdata from bettrans14 and filter by row number
		SET @sql = 
		'SELECT
			b.oddsid,
			CASE
				WHEN sbt.ProductID = 8 THEN 202
				WHEN sbt.ProductID = 28 THEN 220
				ELSE 0
			END AS SportType,
			b.username,
			SUBSTRING(c.username2, CHARINDEX(''$'', c.username2) + 1, LEN(c.username2) - CHARINDEX(''$'', c.username2)) AS Nickname,
			b.bettype,
			0 AS leagueID,
			b.transid,
			'''' AS matchcode,
			'''' AS Race,
			0 AS homeID,
			0 AS awayID,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			(b.winlost - b.actual_stake) AS WinLost,
			CASE
				WHEN b.bettype NOT IN (31,32,33) THEN - (b.winlost-b.actual_stake)
				ELSE awinlost
			END AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			CASE
				WHEN sbt.ProductID IN (1, 2, 3, 5, 27) THEN b.betteam
				ELSE ''''
			END AS BetTeam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid,
			'''' AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			b.custid,
			'''' AS showtime,
			CASE
				WHEN sbt.ProductID = 8 THEN ISNULL(b.comstatus, '''')
				ELSE ''''
			END AS BetCheck,
			ISNULL(b.transdesc, '''') AS transdesc,
			CASE
				WHEN sbt.ProductID = 1 AND b.ExtraInfo LIKE ''%p25%'' THEN
					ISNULL(CAST((''<xml>'' + b.ExtraInfo + ''</xml>'') AS XML).value(''data(/xml/p25/@s)[1]'',''MONEY''), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			CASE
				WHEN sbt.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			ISNULL(b.ExtraInfo, '''') AS ExtraInfo,
			ISNULL(b.WalletType, 0) AS WalletType,
			ISNULL(b.RefCode, 0) AS RefCode,
			CASE
				WHEN sbt.ProductID = 1 THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			-- USD
			b.stake * e.USD stakeUSD,'
			+ @Winlost + ' * e.USD WinlostUSD,'
			+ @LicenseeWL + ' * e.USD LicenseeWLUSD,
			b.comm * e.USD commUSD,
			b.playercomm * e.USD AS PlayerCommUSD,
			CASE
				WHEN sbt.ProductID = 1 AND b.ExtraInfo LIKE ''%p25%'' THEN
					ISNULL(CAST((''<xml>'' + b.ExtraInfo + ''</xml>'') AS XML).value(''data(/xml/p25/@s)[1]'',''MONEY''), 0)
				ELSE 0
			END * e.USD AS OriginalStakeUSD,
			-- EUR
			b.stake * e.EUR stakeEUR,'
			+ @Winlost + ' * e.EUR WinlostEUR,'
			+ @LicenseeWL + ' * e.EUR LicenseeWLEUR,
			b.comm * e.EUR commEUR,
			b.playercomm * e.EUR AS PlayerCommEUR,
			CASE
				WHEN sbt.ProductID = 1 AND b.ExtraInfo LIKE ''%p25%'' THEN
					ISNULL(CAST((''<xml>'' + b.ExtraInfo + ''</xml>'') AS XML).value(''data(/xml/p25/@s)[1]'',''MONEY''), 0)
				ELSE 0
			END * e.EUR AS OriginalStakeEUR,
			-- GBP
			b.stake * e.GBP stakeGBP,'
			+ @Winlost + ' * e.GBP WinlostGBP,'
			+ @LicenseeWL + ' * e.GBP LicenseeWLGBP,
			b.comm * e.GBP commGBP,
			b.playercomm * e.GBP AS PlayerCommGBP,
			CASE
				WHEN sbt.ProductID = 1 AND b.ExtraInfo LIKE ''%p25%'' THEN
					ISNULL(CAST((''<xml>'' + b.ExtraInfo + ''</xml>'') AS XML).value(''data(/xml/p25/@s)[1]'',''MONEY''), 0)
				ELSE 0
			END * e.GBP AS OriginalStakeGBP
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK) 
			INNER JOIN dbo.customer AS c WITH (NOLOCK) ON b.custid = c.custid
			INNER JOIN #TempAg AS ag ON b.recommend = ag.custid AND b.currency = ag.Currency
			INNER JOIN #TempExchange AS e ON e.exchangeid = b.currency
			INNER JOIN #SportBettype AS sbt ON sbt.Bettype = b.bettype' + CHAR(13) +
			CASE
				WHEN @Product = 'BA' THEN 'INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid'	
				ELSE ''
			END + CHAR(13) +
		'WHERE
			b.winlostdate = ''' + CAST(@wldate AS VARCHAR(50)) + '''' + CHAR(13) +
			'AND b.status = ''' + CAST(@status AS VARCHAR(15)) + '''' + CHAR(13) +
			' AND b.bettype NOT IN (9, 29, 10, 2799)
			AND b.ruben = 1' + CHAR(13) +
			CASE
				WHEN @Product = 'SB' THEN 'AND b.tpositiontaking <> 0'
				ELSE ''
			END + CHAR(13)

		INSERT INTO #BetData14 (
			Oddsid,
			Sporttype,
			Username,
			NickName,
			Bettype,
			LeagueID,
			Transid,
			Matchcode,
			Race,
			HomeID,
			AwayID,
			hdp1,
			hdp2,
			odds,
			modds,
			status,
			stake,
			Winlost,
			LicenseeWL,
			comm,
			PlayerComm,
			transdate,
			Winlostdate,
			betteam,
			liveindicator,
			livehomescore,
			liveawayscore,
			MatchID,
			Betstatus,
			IsNeutral,
			oddstype,
			betid,
			currency,
			RefNO,
			CustID,
			showtime,
			betcheck,
			transdesc,
			OriginalStake,
			OriginalBetType,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			OddsSpread,
			stakeUSD,
			WinlostUSD,
			LicenseeWLUSD,
			commUSD,
			PlayerCommUSD,
			OriginalStakeUSD,
			stakeEUR,
			WinlostEUR,
			LicenseeWLEUR,
			commEUR,
			PlayerCommEUR,
			OriginalStakeEUR,
			stakeGBP,
			WinlostGBP,
			LicenseeWLGBP,
			commGBP,
			PlayerCommGBP,
			OriginalStakeGBP)
		EXEC (@sql)

		-- Update LicenseeWL with LicenseeBATransaction table
		UPDATE b
		SET LicenseeWL = 0
			,LicenseeWLUSD = 0
			,LicenseeWLEUR = 0
			,LicenseeWLGBP = 0
		FROM #BetData14 AS b
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid

		-- Update data with match14 table
		UPDATE b
		SET sporttype = m.sporttype,
			leagueID = m.leagueid,
			matchcode = m.matchcode,
			homeID = m.homeid,
			awayID = m.awayid,
			betstatus = m.betstatus,
			IsNeutral = m.IsNeutral,
			showtime = CASE
							WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime, '')
							WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
							ELSE ''
						END
		FROM #BetData14 AS b
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN #SportBettype AS s WITH (NOLOCK) ON b.BetType = s.Bettype
		WHERE s.EventType = 1

		-- Update data with @vhr table
		UPDATE b
		SET sporttype = v.sporttype,
			leagueID = v.leagueid,
			matchcode = v.matchcode,
			homeID = v.RacerID,
			awayID = v.AwayID,
			betstatus = v.BetStatus,
			showtime = v.showtime
		FROM #BetData14 AS b
			INNER JOIN @vhr AS v ON b.oddsid = v.OrID
		WHERE b.bettype IN (1231, 1232, 1233, 1237, 1238)

		-- Update data with @hr table
		UPDATE b
		SET sporttype = r.sporttype,
			leagueID = r.leagueid,
			matchcode = r.matchcode,
			homeID = r.RacerID,
			awayID = r.AwayID,
			betstatus = r.BetStatus,
			Race = r.Race
		FROM #BetData14 AS b
			INNER JOIN @hr AS r ON b.oddsid = r.OrID
		WHERE b.bettype IN (31, 32, 33)

		-- Insert and drop temp table
		INSERT INTO #Data
		SELECT
			sporttype,
			username,
			nickname,
			bettype,
			leagueID,
			transid,
			matchcode,
			Race,
			homeID,
			awayID,
			hdp1,
			hdp2,
			odds,
			modds,
			status,
			stake,
			winlost,
			LicenseeWL,
			comm,
			PlayerComm,
			transdate,
			winlostdate,
			betteam,
			liveindicator,
			livehomescore,
			liveawayscore,
			matchid,
			betstatus,
			IsNeutral,
			OddsType,
			betid,
			currency,
			refno,
			custid,
			showtime,
			betcheck,
			transdesc,
			OriginalStake,
			OriginalBetType,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			OddsSpread,
			stakeUSD,
			WinlostUSD,
			LicenseeWLUSD,
			commUSD,
			PlayerCommUSD,
			OriginalStakeUSD,
			stakeEUR,
			WinlostEUR,
			LicenseeWLEUR,
			commEUR,
			PlayerCommEUR,
			OriginalStakeEUR,
			stakeGBP,
			WinlostGBP,
			LicenseeWLGBP,
			commGBP,
			PlayerCommGBP,
			OriginalStakeGBP
		FROM #BetData14
	
		DROP TABLE #BetData14
	END

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode			BIGINT,
			TransId			BIGINT,
			Stake			MONEY,
			WinLost			MONEY,
			LicenseeWL		MONEY,
			Comm			MONEY,
			PlayerComm		MONEY,
			StakeUSD		MONEY,
			WinLostUSD		MONEY,
			LicenseeWLUSD	MONEY,
			CommUSD			MONEY,
			PlayerCommUSD	MONEY,
			StakeEUR		MONEY,
			WinLostEUR		MONEY,
			LicenseeWLEUR	MONEY,
			CommEUR			MONEY,
			PlayerCommEUR	MONEY,
			StakeGBP		MONEY,
			WinLostGBP		MONEY,
			LicenseeWLGBP	MONEY,
			CommGBP			MONEY,
			PlayerCommGBP	MONEY
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
			SUM(PlayerComm) AS PlayerComm,
			SUM(StakeUSD) AS StakeUSD,
			SUM(WinLostUSD) AS WinLostUSD,
			SUM(LicenseeWLUSD) AS LicenseeWLUSD,
			SUM(CommUSD) AS CommUSD,
			SUM(PlayerCommUSD) AS PlayerCommUSD,
			SUM(StakeEUR) AS StakeEUR,
			SUM(WinLostEUR) AS WinLostEUR,
			SUM(LicenseeWLEUR) AS LicenseeWLEUR,
			SUM(CommEUR) AS CommEUR,
			SUM(PlayerCommEUR) AS PlayerCommEUR,
			SUM(StakeGBP) AS StakeGBP,
			SUM(WinLostGBP) AS WinLostGBP,
			SUM(LicenseeWLGBP) AS LicenseeWLGBP,
			SUM(CommGBP) AS CommGBP,
			SUM(PlayerCommGBP) AS PlayerCommGBP
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
				b.StakeUSD = r.StakeUSD,
				b.WinLostUSD = r.WinLostUSD,
				b.LicenseeWLUSD = r.LicenseeWLUSD,
				b.CommUSD = r.CommUSD,
				b.PlayerCommUSD = r.PlayerCommUSD,
				b.StakeEUR = r.StakeEUR,
				b.WinLostEUR = r.WinLostEUR,
				b.LicenseeWLEUR = r.LicenseeWLEUR,
				b.CommEUR = r.CommEUR,
				b.PlayerCommEUR = r.PlayerCommEUR,
				b.StakeGBP = r.StakeGBP,
				b.WinLostGBP = r.WinLostGBP,
				b.LicenseeWLGBP = r.LicenseeWLGBP,
				b.CommGBP = r.CommGBP,
				b.PlayerCommGBP = r.PlayerCommGBP,
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

	CREATE NONCLUSTERED INDEX IDX_Currency ON #Data(Currency)

	SET @sql = 
		'SELECT A.*
		FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY ' + @Sort + ') AS RowNum,
				d.* 
			FROM #Data d
		) A 
		WHERE A.RowNum BETWEEN ' + CAST(@RowStart AS VARCHAR(50)) + ' AND ' + CAST(@RowEnd AS VARCHAR(50))
		+' ORDER BY A.RowNum'

	EXEC (@sql)

	--SUM
	SELECT * INTO #TempExchangeSum
	FROM Lrf_f_GetExchangeDaily(@wldate, @wldate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM @DataSum)

	SELECT @TotalRows = COUNT(1)
	FROM #Data

	SELECT
		@SumWinlost		= SUM(b.SumWinLost),
		@SumLicenseeWL	= SUM(b.SumLicenseeWL),
		@SumComm		= SUM(b.SumComm),
		@SumPlayerComm	= SUM(ISNULL(b.SumPlayerComm, 0)),
		-- USD
		@SumWinlostUSD		= SUM(b.SumWinLost					* e.USD),
		@SumLicenseeWLUSD	= SUM(b.SumLicenseeWL				* e.USD),
		@SumCommUSD			= SUM(b.SumComm						* e.USD),
		@SumPlayerCommUSD	= SUM(ISNULL(b.SumPlayerComm, 0)	* e.USD),
		-- EUR
		@SumWinlostEUR		= SUM(b.SumWinLost					* e.EUR),
		@SumLicenseeWLEUR	= SUM(b.SumLicenseeWL				* e.EUR),
		@SumCommEUR			= SUM(b.SumComm						* e.EUR),
		@SumPlayerCommEUR	= SUM(ISNULL(b.SumPlayerComm, 0)	* e.EUR),
		-- GBP
		@SumWinlostGBP		= SUM(b.SumWinLost					* e.GBP),
		@SumLicenseeWLGBP	= SUM(b.SumLicenseeWL				* e.GBP),
		@SumCommGBP			= SUM(b.SumComm						* e.GBP),
		@SumPlayerCommGBP	= SUM(ISNULL(b.SumPlayerComm, 0)	* e.GBP)
	FROM @DataSum AS b
		INNER JOIN #TempExchangeSum AS e ON b.currency = e.exchangeid

	-- Get sub tickets
	CREATE TABLE #BettransDetail (
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

	-- Horse Racing
	IF EXISTS (	SELECT TOP(1) 1
				FROM #Data AS b
					INNER JOIN #SportBettype AS sbt ON sbt.Bettype = b.bettype
				WHERE sbt.ProductID = 2)
	BEGIN
		IF @wldate > @MoveBetsDay_
		BEGIN
			INSERT INTO #BettransDetail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.betteam,
				bm.stake * e.EUR,
				bm.stake * e.USD,
				bm.stake * e.GBP
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN #Data AS b ON bm.custid = b.custid AND bm.refno = b.Transid
				INNER JOIN #TempExchange AS e ON e.exchangeid = b.currency
				INNER JOIN #SportBettype AS sbt ON b.Bettype = sbt.BetType
				INNER JOIN #SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE sbt.ProductId = 2 AND sbtm.ProductId = 2
		END

		IF @wldate <= @MoveBetsDay_
		BEGIN
			INSERT INTO #BettransDetail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.betteam,
				bm.stake * e.EUR,
				bm.stake * e.USD,
				bm.stake * e.GBP
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN #Data AS b ON bm.custid = b.custid AND bm.refno = b.Transid
				INNER JOIN #TempExchange AS e ON e.exchangeid = b.currency
				INNER JOIN #SportBettype AS sbt ON b.Bettype = sbt.BetType
				INNER JOIN #SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE sbt.ProductId = 2 AND sbtm.ProductId = 2
		END
	END

	-- Virtual Sports
	IF EXISTS (	SELECT TOP(1) 1
				FROM #Data AS b
					INNER JOIN #SportBettype AS sbt ON sbt.Bettype = b.bettype
				WHERE sbt.ProductID = 5 AND sbt.EventType = 3)
	BEGIN
		IF @wldate > @MoveBetsDay_
		BEGIN
			INSERT INTO #BettransDetail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.betteam,
				bm.stake * e.EUR,
				bm.stake * e.USD,
				bm.stake * e.GBP
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN #Data AS b ON bm.custid = b.custid AND bm.refno = b.Refno
				INNER JOIN #TempExchange AS e ON e.exchangeid = b.currency
				INNER JOIN #SportBettype AS sbt ON b.Bettype = sbt.BetType
				INNER JOIN #SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtm.ProductID = 5
				AND sbtm.EventType = 3
		END

		IF @wldate <= @MoveBetsDay_
		BEGIN
			INSERT INTO #BettransDetail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.betteam,
				bm.stake * e.EUR,
				bm.stake * e.USD,
				bm.stake * e.GBP
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN #Data AS b ON bm.custid = b.custid AND bm.refno = B.Refno
				INNER JOIN #TempExchange AS e ON e.exchangeid = b.currency
				INNER JOIN #SportBettype AS sbt ON b.Bettype = sbt.BetType
				INNER JOIN #SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtm.ProductID = 5
				AND sbtm.EventType = 3
		END
	END

	SELECT * FROM #BettransDetail
	ORDER BY RefNo ASC, Bettype

	DROP TABLE #TempExchange
	DROP TABLE #TempExchangeSum
	DROP TABLE #Data
	DROP TABLE #SportBettype
	DROP TABLE #BettransDetail
	DROP TABLE #TempAg
END









GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossDaily] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossDaily] TO [vnteam]
GO
