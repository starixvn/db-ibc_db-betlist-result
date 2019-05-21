/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_MatchWL_Bettype]
	@AgentList			VARCHAR(MAX),
	@MatchId			INT,
	@BetType			INT				= 0,
	@LiveIndicator		INT				= -1,
	@BaseCurrency		VARCHAR(10),
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinlost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@ShowSB				BIT				= 0,
	@ShowNG				BIT				= 0,
	@ShowVS				BIT				= 0,
	@ShowVS2			BIT				= 0,
	@ShowBA				BIT				= 0,
	@Date				SMALLDATETIME	= NULL,
	@Sort				NVARCHAR(50)	= N'TransId ASC'
AS

/*
	Created: 20101209@Henry
	Task: Betlist
	DB: DBEXT.bodb02
	Original:[Age_BetList_SelWinlossByBettypeMatch_Ag]
	Revisions:
		- 20110214@Jacob: Add column discount IN the result SET
		- 20110216@Jacob: Add column nickname IN the result SET
		- 20110303@Henry: suppport based currency
		- 20110408@Amy: Change function to get Odds value AND odds type
		- 20110712@Henry: Add column LicenseeWL
		- 20110729@Henry: offer 3 new bettypes for Number Game
		- 20111208@Jim: Change condition bettype<31
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change to use table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120726@Jim: add playercomm value
		- 20120817@Jim: add live casino
		- 20120918@Jim: add virtual sport
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20121207@Henry: fix bug 1 match got 2 different winlostdate by add param @Date
		- 20130417@Jim: support base currency USD
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130904@Jim: support Virtual Horse Racing
		- 20140630@Hannah: offer BetRadar and Sporting Solution
		- 20140908@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141021@Florent: Apply for the change in Sporting Solution structure (#24478)
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150128@Winnie: Add base currency GBP
		- 20150406@Winnie: Apply matrix of sporttype & bettype & Add 60 bettype betradar
		- 20150609@Edward: Exclude 3 transactions SOLD/BOUGHT/BetTrade Commission of BetTrade
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160516@Kos: Add sorting function [#Redmine: 57433]
		- 20160714@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20161004@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170223@Kos: Support sub licensees [#Redmine: 71679]
		- 20170303@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170830@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180305@Kos: Don't support Live Casino anymore [#Redmine: 85965]
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]
		- 20180329@Kos: Support Fast Market 2 [#Redmine: 90879]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190521@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Change input param @Sort data type from VARCHAR(100) to NVARCHAR(50)
					- Remove params @SumWinLostUSD, @SumWinLostEUR, @SumWinLostGBP, ...
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

	DECLARE @_Date SMALLDATETIME

	IF @Date IS NOT NULL
		SET @_Date = @Date

	SELECT @BetType = ISNULL(@BetType, 0)

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 3, 5, 27)

	DELETE @SportBettype
	WHERE Bettype IN (901, 902, 903, 904, 911, 912, 913, 914)

	DELETE @SportBettype
	WHERE ProductID		= CASE WHEN @ShowSB	= 0 AND @ShowBA = 0 THEN 1 END
		OR ProductID	= CASE WHEN @ShowNG	= 0 THEN 3 END
		OR ProductID	= CASE WHEN @ShowVS	= 0 THEN 5 END
		OR ProductID	= CASE WHEN @ShowVS2 = 0 THEN 27 END
	-- end filer bettypes by sporttype

	CREATE TABLE #Data (
		SportType		INT,
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		CustId			INT,
		BetType			INT,
		LeagueId		INT,
		TransId			BIGINT,
		MatchCode		VARCHAR(50),
		EventDate		DATETIME,
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
		WinLostDate		SMALLDATETIME,
		BetTeam			NVARCHAR(10),
		LiveIndicator	INT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		MatchId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		OddsType		INT,
		BetId			BIGINT,
		Currency		SMALLINT,
		RefNo			BIGINT,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		WalletType		TINYINT,
		RefCode			BIGINT,
		OddsSpread		MONEY
	)

	CREATE TABLE #ExchangeRate (
		ExchangeId					INT,
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	IF EXISTS (SELECT TOP(1) 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchId
		UNION SELECT TOP(1) 1 FROM dbo.VSOutright WITH (NOLOCK) WHERE EventID = @MatchId )
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				'' AS Nickname,
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
				b.status,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
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
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
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
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
			WHERE
				b.matchid = @MatchId
				AND (@BetType = 0
					OR (@BetType <> 0 AND CASE WHEN ISNULL(ss.bettype, 0) = 0 THEN b.bettype ELSE ss.Grouptypeid END = @BetType))
				AND sbt.ProductID = 1
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking = 0
				AND ((@LiveIndicator = -1)
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				'' AS Nickname,
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
				b.status,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
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
				ISNULL(b.WalletType, 0) AS WalletType,
				ISNULL(b.RefCode, 0) AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
			WHERE
				b.matchid = @MatchId
				AND (@BetType = 0
					OR (@BetType <> 0 AND CASE WHEN ISNULL(ss.bettype,0) = 0 THEN b.bettype ELSE ss.Grouptypeid END = @BetType))
				AND sbt.ProductID = 1
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking <> 0
				AND ((@LiveIndicator = -1)
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END

		-- Number Game, Virtual Sports, Betradar Virtual Sports (EventType = 1)
		IF @ShowNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				b.winlostdate AS EventDate,
				m.homeid,
				m.awayid,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				CASE
					WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE ISNULL(m.showtime, '')
				END AS ShowTime,
				'' AS betcheck,
				CASE
					WHEN sbt.ProductID = 27 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.matchid = @MatchId
				AND (@BetType = 0
					OR (@BetType <> 0 AND b.bettype = @BetType))
				AND sbt.ProductID IN (3, 5, 27)
				AND sbt.EventType = 1
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = -1) 
					OR (@LiveIndicator = 0 AND b.liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END

		-- Virtual Sports (EventType = 3)
		IF @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				r.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				r.leagueID,
				b.transid,
				CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
				b.winlostdate AS EventDate,
				o.RacerID AS homeID,
				0 AS awayID,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				o.EventID matchid,
				r.betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				CONVERT(VARCHAR(20), r.EventTime) AS ShowTime,
				'' AS betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				o.EventID = @MatchId
				AND (@BetType = 0
					OR (@BetType <> 0 AND b.bettype = @BetType))
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = -1)
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END
	END
	ELSE
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				'' AS Nickname,
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
				b.status,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
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
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
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
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
			WHERE
				b.matchid = @MatchId
				AND (@BetType = 0
					OR (@BetType <> 0 AND CASE WHEN ISNULL(ss.bettype,0) = 0 THEN b.bettype ELSE ss.Grouptypeid END = @BetType))
				AND sbt.ProductID = 1
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking = 0
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
				AND 1 = CASE @LiveIndicator
							WHEN 0 THEN CASE WHEN b.Liveindicator = 0 THEN 1 ELSE 0 END
							WHEN 1 THEN CASE WHEN b.Liveindicator = 1 THEN 1 ELSE 0 END
							ELSE 1
						END
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				'' AS Nickname,
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
				b.status,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.OddsType,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
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
				ISNULL(b.WalletType, 0) AS WalletType,
				ISNULL(b.RefCode, 0) AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
			WHERE
				b.matchid = @MatchId
				AND (@BetType = 0
					OR (@BetType <> 0 AND CASE WHEN ISNULL(ss.bettype,0) = 0 THEN b.bettype ELSE ss.Grouptypeid END = @BetType))
				AND sbt.ProductID = 1
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = -1)
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END

		-- Number Game, Virtual Sports, Betradar Virtual Sports (EventType = 1)
		IF @ShowNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				b.winlostdate AS EventDate,
				m.homeid,
				m.awayid,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				CASE
					WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE ISNULL(m.showtime, '')
				END AS ShowTime,
				'' AS betcheck,
				CASE
					WHEN sbt.ProductID = 27 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.matchid = @MatchId
				AND (@BetType = 0
					OR (@BetType <> 0 AND b.bettype = @BetType))
				AND sbt.ProductID IN (3, 5, 27)
				AND sbt.EventType = 1
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = -1)
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END

		-- Virtual Sports (EventType = 3)
		IF @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				r.SportType,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				r.LeagueID,
				b.transid,
				CONVERT (VARCHAR(50), o.RacerNum) matchcode,
				b.winlostdate AS EventDate,
				o.RacerID AS homeID,
				0 AS awayID,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				r.EventID AS matchid,
				r.betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				CONVERT(VARCHAR(20), r.EventTime) AS ShowTime,
				'' AS betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				o.EventID = @MatchId
				AND (@BetType = 0
					OR (@BetType <> 0 AND b.bettype = @BetType))
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = -1)
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END
	END

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

	-- Get exchange rate
	DECLARE @Today SMALLDATETIME

	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM #Data

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
			WHEN @BaseCurrency = 'INH' THEN e.INH
			ELSE 1
		END AS Rate
	FROM dbo.Lrf_f_GetSubExchangeDaily(@ExFromDate, @ExToDate) AS e
	WHERE EXISTS (SELECT 1 FROM #Data
				WHERE Currency = e.ExchangeId
					AND WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)

	-- Return data
	SELECT
		@TotalRows		= COUNT(b.TransId),
		@SumWinlost		= SUM(b.WinLost		* ISNULL(e.Rate, 1)),
		@SumLicenseeWL	= SUM(b.LicenseeWL	* ISNULL(e.Rate, 1)),
		@SumComm		= SUM(b.Comm		* ISNULL(e.Rate, 1)),
		@SumPlayerComm	= SUM(b.PlayerComm	* ISNULL(e.Rate, 1))
	FROM #Data AS b
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = b.Currency
				AND CASE
						WHEN b.WinLostDate > @Today THEN @Today
						ELSE b.WinLostDate
					END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

	UPDATE #Data
	SET Nickname = SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2))
	FROM #Data AS b
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid

	CREATE TABLE #PagingData (
		RowNum			INT,
		SportType		INT,
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		CustId			INT,
		BetType			INT,
		LeagueId		INT,
		TransId			BIGINT,
		MatchCode		VARCHAR(50),
		EventDate		DATETIME,
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
		WinLostDate		SMALLDATETIME,
		BetTeam			NVARCHAR(10),
		LiveIndicator	INT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		MatchId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		OddsType		INT,
		BetId			BIGINT,
		Currency		SMALLINT,
		RefNo			BIGINT,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		WalletType		TINYINT,
		RefCode			BIGINT,
		OddsSpread		MONEY
	)

	-- Exchange rate is different for each day => Stake order may be different from StakeUSD order
	IF @Sort LIKE '%Stake%' OR @Sort LIKE '%WinLost%' OR @Sort LIKE '%LicenseeWL%'
	BEGIN
		DECLARE @CharIndex TINYINT

		SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

		SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(e.Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
	END

	IF @Sort NOT LIKE '%TransId%'
	BEGIN
		SELECT @Sort = @Sort + ', TransId ASC'
	END

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Sql NVARCHAR(1000)

	SET @Sql = 
		'DECLARE @Today SMALLDATETIME

		SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

		SELECT a.*
		FROM
			(
				SELECT
					ROW_NUMBER() OVER (ORDER BY ' + @Sort + ') AS RowNum,
					b.*
				FROM #Data AS b' +
				CASE
					WHEN @Sort LIKE '%e.Rate%' THEN N'
					LEFT JOIN #ExchangeRate AS e
						ON e.ExchangeId = b.Currency
							AND CASE
									WHEN b.WinLostDate > @Today THEN @Today
									ELSE b.WinLostDate
								END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth'
					ELSE N' '
				END + N'
			) AS a
		WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
		ORDER BY a.RowNum'

	INSERT INTO #PagingData
	EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

	DROP TABLE #Data

	SELECT
		b.RowNum,
		b.SportType,
		b.Username,
		b.Nickname,
		b.CustId,
		b.BetType,
		b.LeagueId,
		b.TransId,
		b.MatchCode,
		b.HomeId,
		b.AwayId,
		b.Hdp1,
		b.Hdp2,
		b.Odds,
		b.Status,
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
		b.BetStatus,
		b.IsNeutral,
		b.OddsType,
		b.BetId,
		b.Currency,
		b.RefNo,
		b.ShowTime,
		b.BetCheck,
		b.TransDesc,
		b.BetdaqId,
		b.ExtraInfo,
		b.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		b.OriginalBetType,
		b.WalletType,
		b.RefCode,
		b.OddsSpread
	FROM #PagingData AS b
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = b.Currency
				AND CASE
						WHEN b.WinLostDate > @Today THEN @Today
						ELSE b.WinLostDate
					END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY b.RowNum ASC

	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10)
	)

	-- Virtual Sports
	IF @ShowVS = 1
	BEGIN
		IF EXISTS (SELECT TOP(1) 1 FROM dbo.VSOutright WITH (NOLOCK) WHERE EventID = @MatchId)
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bg.refno,
				bg.odds,
				bg.stake * ISNULL(e.Rate, 1) AS Stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.betteam
			FROM dbo.bettransm AS bg WITH (NOLOCK)
				INNER JOIN #PagingData AS b ON bg.refno = b.RefNo AND bg.custid = b.CustId
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
				LEFT JOIN #ExchangeRate AS e
					ON e.ExchangeId = b.Currency
						AND CASE
								WHEN b.WinLostDate > @Today THEN @Today
								ELSE b.WinLostDate
							END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			WHERE sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtg.ProductID = 5
				AND sbtg.EventType = 3
		END

		IF EXISTS (SELECT TOP(1) 1 FROM dbo.VSOutright14 WITH (NOLOCK) WHERE EventID = @MatchId)
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bg.refno,
				bg.odds,
				bg.stake * ISNULL(e.Rate, 1) AS Stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.betteam
			FROM dbo.bettransm14 AS bg WITH (NOLOCK)
				INNER JOIN #PagingData AS b ON bg.refno = b.RefNo AND bg.custid = b.CustId
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
				LEFT JOIN #ExchangeRate AS e
					ON e.ExchangeId = b.Currency
						AND CASE
								WHEN b.WinLostDate > @Today THEN @Today
								ELSE b.WinLostDate
							END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			WHERE sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtg.ProductID = 5
				AND sbtg.EventType = 3
		END
	END

	SELECT DISTINCT * FROM @BettransDetail
	ORDER BY RefNo ASC, Bettype ASC

	DROP TABLE #ExchangeRate
	DROP TABLE #PagingData
END
GO




GRANT EXECUTE ON [dbo].[Lrf_BetList_MatchWL_Bettype] TO [bodbLicenseeNet]
GO
