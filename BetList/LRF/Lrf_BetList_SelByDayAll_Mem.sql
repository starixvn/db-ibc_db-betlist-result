/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_SelByDayAll_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@FromDate		SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@TransType		INT				= 0,
	@BaseCurrency	VARCHAR(10),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0 OUTPUT,
	@SumWinLost		MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT,
	@SumComm		MONEY			= 0 OUTPUT,
	@SumPlayerComm	MONEY			= 0 OUTPUT
AS

/*
	Created: Henry@20101210
	Task: Bet List for Daily Statement
	DB: DBEXT.bodb02
	Original: Age_BetList_SelByDayAll_Mem
	Revisions:
		- 20110214@Jacob: Add column discount IN the result SET
		- 20110303@Henry: suppport based currency
		- 20110408@Amy: Change function to get Odds value AND odds type
		- 20110712@Henry: Add column LicenseeWL
		- 20110725@Henry: Get refund tickets
		- 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mix Parlay
		- 20111128@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
		- 20111212@Jim: Edit condition bettype<19000
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120319@Henry: show main transid for sub-ticket of system parlay
		- 20120724@Jim: add player commision value
		- 20120817@Jim: add live casino
		- 20120913@Jim: add virtual sport 
		- 20130410@Jim: return betteam value for Parlay (mix parlay & system parlay) ticket
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130905@Jim: support VHR
		- 20140310@Hannah: offer Keno
		- 20140324@Daniel: fix show RNG Casino / Bingo bets due to matchid = 0
		- 20140411@Francis: fix incorrect sporttypes showing for VHR, Racing
		- 20140630@Hannah: offer BetRadar and Sporting Solution
		- 20141121@Jim: support multiple currency per one member
		- 20150128@Winnie: Add currency GBP
		- 20150413@Bobby: Re-format code  & #32844 new 60 bettypes - betradar phase 2
		- 20150511@Kiwi: Fixed the bug (RedmineID: #35562)
		- 20150608@Edward: Support Microgaming
		- 20150608@Edward: Support Bet Trade
		- 20150729@Edward: Return betcheck for Microgaming
		- 20150806@Edward: Fixed bug return 0 instead of game id for Microgaming
		- 20150831@Edward: Fixed bettrade performance and odds value
		- 20150916@Kos: Support Microgaming RNG Casino
		- 20150923@Kos: Support AG Casino
		- 20151028@Kos: Change ProductId, SportType of Microgaming RNG Casino
		- 20151124@Kos: Support Microgaming RNG Casino Jackpot Grand Prize ticket
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151228@Kos: Support RNG Casino Single Wallet
		- 20160202@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160216@Kos: Support yesterday running ticket [Redmine: #52277]
		- 20160406@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160413@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160718@Kos: Remove Bingo and change to use inline function for SportBettypeMatrix
		- 20160727@Kos: Support AllBet [#Redmine: 61066]
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160913@Kos: Support Colossus Bets [#Redmine: 63785]
		- 20161007@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20161114@Kos: Support Fishing World [#Redmine: 66737]
		- 20170303@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20170330@Kos: Support CashOut [#Redmine: 71963]
		- 20170605@Kos: Get liveindicator from original ticket for 911 and 912 tickets [#Redmine: 77669]
		- 20170622@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170628@Kos: Hotfix - CashOut Details link in Racing tickets [#Redmine: 79076]
		- 20170724@Kos: Support Keno Lottery [#Redmine: 79997]
		- 20170830@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180305@Kos: Don't support Live Casino anymore [#Redmine: 85965]
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]
		- 20180329@Kos: Support Fast Market 2 [#Redmine: 90879]
		- 20180510@Kos: Support Keno 6 new Mini Games [#Redmine: 94829]
		- 20180525@Kos: Support Pragmatic Casino [#Redmine: 92318]
		- 20180806@Kos: Don't support Racing anymore [#Redmine: 99378]
		- 20181102@Patrick: DB052 indexes revolution [RedmineID :#103572]
		- 20181108@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 107165]
		- 20190401@Kos: Don't support Microgaming Live Casino and Microgaming RNG Casino anymore [#Redmine: 107704]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190527@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Remove params @ErrCode, @ErrMsg
					- Remove params @SumWinLostUSD, @SumWinLostEUR, @SumWinLostGBP, ...
		- 20190627@Kos: Support PH AIO 4a [Redmine: #115448]
		- 20190729@Kos: Support new status Pending [#Redmine: 117729]
		- 20190813@Kos: Support Card Club [Redmine: #115449]
		- 20191011@Kos: Support drop table LicenseeBATransaction [Redmine: #103656]
		- 20191031@Kos: Show Running status for Marked tickets [Redmine: 120309]
		- 20191105@Kos: Support Non-peak Hours Promotion [#Redmine: 121121]
		- 20191209@Kos: Support Spadegaming [Redmine: #124103]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200208@Kos: Support Virtual Games [Redmine: #124911]
		- 20200402@Kos: Support Table Games [Redmine: #131447]
		- 20200416@Kos: Support Indo 4D [Redmine: #130859]
		- 20200502@Kos: Support Table Game Half Won Half Lose [Redmine: #133323]
		- 20200511@Kos: Support Saba.club [Redmine: #131447]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20200714@Kos: Support PP Jackpot [Redmine: #137290]
		- 20200728@Kos: Support SA Gaming [Redmine: #128493]
		- 20200815@Kos: Support PG Soft [Redmine: #139182]
		- 20200922@Kos: Support Joker [Redmine: #141408]
		- 20201210@Kos: Exclude bettype 999 Odds Spread Adjustment [Redmine: #142532]
		- 20201231@Kos: Support Happy 5 Linked Games [Redmine: #147446]

	Param's Explanation:
		+ @TransType:
			1: Won/Lose/Draw/Refund ticket
			2: Void/Reject ticket
			3: Running/Waiting ticket
			4: Grand Prize ticket (Colossus Bets)
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

	/*
		WON: 112, LOSE: 113, DRAW: 111, REFUND: 103
		VOID: 102, REJECT: 101
		RUNNING: 0, WAITING: 1
	*/
	DECLARE @tmpStatus TABLE ([statusID] INT)

	IF @TransType = 1
	BEGIN
		INSERT INTO @tmpStatus([statusID])
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 103
	END
	ELSE IF @TransType = 2
	BEGIN
		INSERT INTO @tmpStatus([statusID])
		SELECT 101 UNION ALL
		SELECT 102
	END
	ELSE IF @TransType = 3
	BEGIN
		INSERT INTO @tmpStatus([statusID])
		SELECT 0 UNION ALL
		SELECT 1
	END
	ELSE IF @TransType = 4
	BEGIN
		INSERT INTO @tmpStatus([statusID])
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113
	END

	DECLARE @Yesterday SMALLDATETIME
		, @Today SMALLDATETIME

	SELECT @Today = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
		, @Yesterday = DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)

	DECLARE @Data TABLE (
		SportType			INT,
		LeagueId			INT,
		HomeId				INT,
		AwayId				INT,
		BetType				SMALLINT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		MatchId				INT,
		TransId				BIGINT,
		TransDate			DATETIME,
		WinLostDate			DATETIME,
		RefNo				NVARCHAR(50),
		BetId				BIGINT,
		OddsId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Modds				MONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		BetTeam				NVARCHAR(50),
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		BetStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		Discount			DECIMAL(9,8),
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		LiveIndicator		BIT,
		FinalHomeScore		SMALLINT,
		FinalAwayScore		SMALLINT,
		HtHomeScore			SMALLINT,
		HtAwayScore			SMALLINT,
		Ip					NVARCHAR(20),
		Username			NVARCHAR(50),
		IsNeutral			BIT,
		Currency			SMALLINT,
		ShowTime			NVARCHAR(50), -- table - shoe - hand of Live Casino
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

	-- filer bettypes by sporttype
	DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 3, 5, 6, 8, 11, 15, 21, 22, 24, 25, 27, 28, 32, 34, 36, 37, 38, 39, 40, 42, 43, 45, 55, 56)

	DELETE @SportBettype
	WHERE Bettype IN (904, 914, 999)

	IF @TransType = 3	-- Don't support running RNG Casino old bet type (71)
	BEGIN
		DELETE @SportBettype
		WHERE ProductID = 6 AND SubProduct = ''
	END

	IF @TransType = 4	-- support only for Colossus Bets
	BEGIN
		DELETE @SportBettype
		WHERE ProductID NOT IN (15)
	END

	-- END filer bettypes

	IF @FromDate <= @MoveBetsDay
	BEGIN
		-- single bet
		INSERT INTO @Data
		SELECT
			m.sporttype,
			m.leagueid,
			m.homeid,
			m.awayid,
			b.bettype,
			m.matchcode,
			'' AS race,
			m.GlobalShowTime AS EventDate,
			m.matchid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			b.betid,
			b.oddsid,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.betteam,
			b.status,
			0 AS SettlementStatus,
			m.betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			CASE
				WHEN BA.transid IS NULL THEN - (b.winlost - b.actual_stake)
				ELSE 0
			END AS LicenseeWL,
			CASE
				WHEN b.bettype IN (903, 913) THEN b.awinlost
				ELSE b.comm
			END AS comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.finalhomescore,
			m.finalawayscore,
			m.hthomescore,
			m.htawayscore,
			b.ip,
			b.Username,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency,
			CASE
				WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE ''
			END AS ShowTime,
			CASE 
				WHEN sbt.ProductID = 1 THEN b.betcheck 
				ELSE '' 
			END AS betcheck,
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
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			CASE
				WHEN sbt.ProductID = 1 THEN ISNULL(b.WalletType, 0)
				ELSE 0
			END AS WalletType,
			CASE
				WHEN sbt.ProductID = 1 THEN ISNULL(b.RefCode, 0)
				ELSE 0
			END AS RefCode,
			CASE
				WHEN sbt.ProductID = 1 THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk AS BA WITH (NOLOCK) ON b.transid = BA.transid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE
			b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND sbt.EventType = 1
			AND b.statusID IN (SELECT statusID FROM @tmpStatus)

		-- RNG Casino
		INSERT INTO @Data
		SELECT
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN 251
				WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
				ELSE 0
			END AS Sporttype,
			0 AS leagueid,
			0 AS homeID,
			0 AS awayID,
			b.bettype,
			'' AS matchcode,
			'' AS race,
			b.WinLostDate AS EventDate,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.bettype
				ELSE 0
			END AS MatchId,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			b.betid,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddsid
				ELSE 0
			END AS oddsid,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp1
				ELSE 0
			END AS hdp1,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp2
				ELSE 0
			END AS hdp2,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.modds
				ELSE 0
			END AS modds,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddstype
				ELSE 0
			END AS Oddstype,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Odds
				ELSE 0
			END AS Odds,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Betteam
				ELSE ''
			END AS Betteam,
			b.status,
			0 AS SettlementStatus,
			'' AS betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.livehomescore
				ELSE ''
			END AS livehomescore,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.liveawayscore
				ELSE ''
			END AS liveawayscore,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.liveindicator
				ELSE ''
			END AS liveindicator,
			0 AS FinalHomeScore, 
			0 AS FinalAwayScore,
			0 AS hthomescore, 
			0 AS htawayscore,
			b.ip,
			b.Username,
			0 AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
				ELSE ''
			END AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND sbt.ProductID = 6
			AND sbt.EventType = 0
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Virtual Horse Racing
		INSERT INTO @Data 
		SELECT
			r.sporttype,
			r.leagueid,
			o.RacerID AS homeID,
			0 awayID,
			b.bettype,
			CONVERT(VARCHAR(50), o.RacerNum) AS matchcode,
			'' AS race,
			b.WinLostDate AS EventDate,
			o.EventID AS matchid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			b.betid,
			b.oddsid,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.Oddstype,
			b.odds,
			b.betteam,
			b.status,
			0 AS SettlementStatus,
			r.betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			0 AS FinalHomeScore,
			0 AS FinalAwayScore,
			0 AS hthomescore,
			0 AS htawayscore,
			b.ip,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			CONVERT(VARCHAR(20),r.eventTime) AS ShowTime,
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
			INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE
			b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND sbt.ProductId = 5
			AND sbt.EventType = 3
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Mix Parlay, System Parlay (Sportsbook), Mix Parlay (Betradar Virtual Sports)
		INSERT INTO @Data
		SELECT
			0,
			0,
			0,
			0,
			b.bettype,
			'',
			'' AS race,
			b.WinLostDate AS EventDate,
			0, 
			CASE
				WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			0,
			0,
			b.hdp1,
			b.hdp2,
			b.modds,
			0 AS OddsType,
			b.odds,
			b.betteam,
			b.status,
			0 AS SettlementStatus,
			'' betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			CASE
				WHEN BA.transid IS NULL THEN - (b.winlost - b.actual_stake)
				ELSE 0 END
			AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			b.ip,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM 
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND sbt.ProductID IN (1, 27)
			AND sbt.EventType = 0
			AND b.statusID IN (SELECT statusID FROM @tmpStatus)

		-- Outright
		INSERT INTO @Data 
		SELECT
			l.sporttype,
			m.leagueID,
			m.teamID AS homeid,
			0 AS awayid,
			b.bettype,
			m.matchcode,
			m.groupmatch AS race,
			b.WinLostDate AS EventDate,
			m.orid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			0,
			10,
			b.hdp1,
			b.hdp2,
			b.modds,
			0 AS OddsType,
			b.odds,
			'',
			b.status,
			0 AS SettlementStatus,
			'', 
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			CASE
				WHEN ISNULL(BA.transid, 0) = 0 THEN - (b.winlost - b.actual_stake)
				ELSE 0
			END AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			0,
			0,
			0,
			0,
			0,
			b.IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM 
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.outright14 AS m WITH (NOLOCK) on b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) on m.leagueid = l.leagueid
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND b.bettype = 10
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Keno, AG Casino, AllBet, Macau Games, Fishing World, Lottery, Pragmatic Casino, Card Club, Spadegaming, NPH Promotion
		-- Virtual Games, SA Gaming, Table Games, Indo 4D, Sexy Gaming, Saba.club, PG Soft, Joker, Happy 5 Linked Games
		IF @TransType = 1 OR @TransType = 2
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN sbt.ProductID = 8 THEN 202
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 21 THEN 211
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 24 THEN 219
					WHEN sbt.ProductID = 28 THEN 220
					WHEN sbt.ProductID = 32 THEN 248
					WHEN sbt.ProductID IN (3, 34, 36, 37, 38, 39, 40, 42, 43, 45, 55, 56) THEN b.matchid
					ELSE 0
				END AS SportType,
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				b.bettype,
				'' AS matchcode,
				'' AS race,
				b.WinLostDate AS EventDate,
				0 AS matchid,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS betid,
				0 AS oddsid,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS Oddstype,
				CASE
					WHEN sbt.ProductID IN (8, 28, 32, 38, 40, 43) THEN b.odds
					ELSE 0
				END AS Odds,
				'' AS betteam,
				CASE
					WHEN sbt.ProductID = 40 AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
					WHEN sbt.ProductID = 40 AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
					ELSE b.status
				END AS status,
				0 AS SettlementStatus,
				'' AS betstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductID = 8 THEN ISNULL(b.comstatus, '')
					WHEN sbt.ProductID IN (3, 38) THEN ISNULL(b.betcheck, '')
					ELSE ''
				END AS betcheck,
				CASE
					WHEN sbt.ProductID IN (3, 8, 22, 24, 28, 32, 34, 36, 38, 40, 43, 55, 56) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				-1 AS BetdaqId,
				CASE
					WHEN sbt.ProductID = 37 THEN ISNULL(b.ExtraInfo, '')
					ELSE ''
				END AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				CASE
					WHEN sbt.ProductID = 32 THEN ISNULL(b.oddsspread, 0)
					ELSE 0
				END AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			WHERE
				b.custid = @CustId
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID IN (3, 8, 11, 21, 22, 24, 28, 32, 34, 36, 37, 38, 39, 40, 42, 43, 45, 55, 56)
				AND sbt.EventType = 0
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND @TransType <> 4
		END

		-- Colossus Bets
		IF @TransType <> 4
		BEGIN
			INSERT INTO @Data
			SELECT
				204 AS SportType,
				0 AS LeagueId,
				0 AS HomeId,
				0 AS AwayId,
				b.bettype,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS MatchId,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS BetId,
				0 AS OddsId,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsYype,
				0 AS Odds,
				'' AS BetTeam,
				b.status,
				0 AS SettlementStatus,
				'' AS BetStatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.custid = @CustId
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID = 15
				AND sbt.EventType = 0
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END

		-- Grand Prize Jackpot Win
		IF @TransType = 4
		BEGIN
			-- Colossus Bets
			INSERT INTO @Data
			SELECT
				204 AS SportType,
				0 AS LeagueId,
				0 AS HomeId,
				0 AS AwayId,
				b.bettype,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS MatchId,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS BetId,
				0 AS OddsId,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				0 AS Odds,
				'' AS BetTeam,
				b.status,
				0 AS SettlementStatus,
				'' AS BetStatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				b.transdesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND sbt.ProductID = 15
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND EXISTS (	SELECT 1 
								FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
								WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
		END

		-- Get more info for BetTrade tickets
		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType IN (901, 902))
		BEGIN
			UPDATE betList
			SET betList.Odds = originBetList.Odds,
				betList.Stake = originBetList.Stake,
				betList.LiveHomeScore = originBetList.livehomescore,
				betList.LiveAwayScore = originBetList.liveawayscore,
				betList.Comm = CASE
									WHEN betList.BetType = 902 THEN commBetList.comm
									ELSE betList.comm
								END,
				betList.BetId = originBetList.Bettype
			FROM @Data AS betList
				INNER JOIN dbo.bettrans14 AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.transid
				LEFT JOIN @Data AS commBetList ON betList.RefNo = commBetList.RefNo AND commBetList.BetType = 903
			WHERE betList.SportType = 1 AND betList.BetType IN (901, 902)
		END

		-- Get more info for CashOut tickets
		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911)
		BEGIN
			UPDATE b
			SET b.Odds = ob.odds,
				b.LiveIndicator = ob.liveindicator,
				b.LiveHomeScore = ob.livehomescore,
				b.LiveAwayScore = ob.liveawayscore,
				b.OriginalBetType = ob.bettype,
				b.BetdaqId = ob.transid
			FROM @Data AS b
				INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
			WHERE b.BetType = 911
		END

		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912)
		BEGIN
			UPDATE b
			SET b.Odds = ob.odds,
				b.LiveIndicator = ob.liveindicator,
				b.LiveHomeScore = ob.livehomescore,
				b.LiveAwayScore = ob.liveawayscore,
				b.OriginalBetType = ob.bettype,
				b.BetdaqId = ob.transid,
				b.Stake = cob.stake,
				b.Comm = ISNULL(cb.Comm, 0)
			FROM @Data AS b
				INNER JOIN dbo.bettrans14 AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
				INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
				LEFT JOIN @Data AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
			WHERE b.BetType = 912
		END

		DELETE @Data
		WHERE BetType IN (903, 913)
	END
	ELSE
	BEGIN
		-- single bet
		INSERT INTO @Data 
		SELECT
			m.sporttype,
			m.leagueid,
			m.homeID,
			m.awayID,
			b.bettype,
			m.matchcode,
			'' AS race,
			m.GlobalShowTime AS EventDate,
			m.matchid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			b.betid,
			b.oddsid,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.betteam,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1
					AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			m.betstatus,
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.statusID NOT IN (0,1) THEN (b.winlost-b.actual_stake)
				ELSE 0 
			END AS WinLost,
			CASE
				WHEN b.statusID NOT IN (0,1) THEN
					CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END 
				ELSE 0
			END AS LicenseeWL,
			CASE
				WHEN b.bettype IN (903, 913) THEN b.awinlost
				ELSE
					CASE WHEN b.statusID NOT IN (0,1) THEN b.comm ELSE 0
					END
			END AS comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.finalhomescore,
			m.finalawayscore,
			m.hthomescore,
			m.htawayscore,
			b.ip,
			b.Username,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency,
			CASE
				WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE ''
			END AS ShowTime,
			CASE 
				WHEN sbt.ProductID = 1 THEN b.betcheck
				ELSE '' 
			END AS betcheck,
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
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			CASE
				WHEN sbt.ProductID = 1 THEN ISNULL(b.WalletType, 0)
				ELSE 0
			END AS WalletType,
			CASE
				WHEN sbt.ProductID = 1 THEN ISNULL(b.RefCode, 0)
				ELSE 0
			END AS RefCode,
			CASE
				WHEN sbt.ProductID = 1 THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND sbt.EventType = 1
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- RNG Casino
		INSERT INTO @Data
		SELECT
			251 AS Sporttype,
			0 AS leagueid,
			0 AS homeID,
			0 AS awayID,
			b.bettype,
			'' AS matchcode,
			'' AS race,
			b.WinLostDate AS EventDate,
			b.bettype AS matchid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			b.betid,
			b.oddsid,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.betteam,
			b.status,
			0 AS SettlementStatus,
			'' betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			0 AS FinalHomeScore,
			0 AS FinalAwayScore,
			0 AS hthomescore,
			0 AS htawayscore,
			b.ip,
			b.Username,
			0 AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND (sbt.ProductID = 6 AND sbt.SubProduct = '')
			AND sbt.EventType = 0
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Virtual Horse Racing
		INSERT INTO @Data
		SELECT
			r.sporttype,
			r.leagueid,
			o.RacerID AS homeID,
			0 awayID,
			b.bettype,
			CONVERT(VARCHAR(50),o.RacerNum) AS matchcode,
			'' AS race,
			b.WinLostDate AS EventDate,
			o.EventID AS matchid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			b.betid,
			b.oddsid,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.Oddstype,
			b.odds,
			b.betteam,
			b.status,
			0 AS SettlementStatus,
			r.betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			0 AS FinalHomeScore,
			0 AS FinalAwayScore,
			0 AS hthomescore,
			0 AS htawayscore,
			b.ip,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			CONVERT(VARCHAR(20), r.eventTime) AS ShowTime,
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
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE
			b.custid = @CustId
			AND b.winlostdate = @FromDate 
			AND sbt.ProductId = 5 
			AND sbt.EventType = 3
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Mix Parlay, System Parlay (Sportsbook), Mix Parlay (Betradar Virtual Sports)
		INSERT INTO @Data
		SELECT
			0,
			0,
			0,
			0,
			b.bettype,
			'',
			'',
			b.WinLostDate AS EventDate,
			0,
			CASE
				WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			0,
			0,
			b.hdp1,
			b.hdp2,
			b.modds,
			0 AS OddsType,
			b.odds,
			b.betteam,
			CASE
				WHEN b.status = 'running' THEN
					CASE
						WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
									WHERE bm.custid = @CustId
										AND bm.refno = b.refno
										AND (bm.status = 'waiting'
											OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
							THEN 'Waiting'
						ELSE b.status
					END
				ELSE b.status
			END AS Status,
			0 AS SettlementStatus,
			'' betstatus,
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.statusID NOT IN (0, 1) THEN (b.winlost - b.actual_stake)
				ELSE 0
			END AS WinLost,
			CASE
				WHEN b.statusID NOT IN (0,1) THEN 
					CASE
						WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END
				ELSE 0
			END AS LicenseeWL,
			CASE WHEN b.statusID NOT IN (0,1) THEN b.comm ELSE 0 END AS comm,
			b.playercomm,
			b.discount,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			b.ip,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND sbt.ProductID IN (1, 27)
			AND sbt.EventType = 0
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Outright
		INSERT INTO @Data
		SELECT
			l.sporttype,
			m.leagueID,
			m.teamID AS homeid,
			0 AS awayid,
			b.bettype,
			m.matchcode,
			m.groupmatch AS race,
			b.WinLostDate AS EventDate,
			m.orid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			0,
			10,
			b.hdp1,
			b.hdp2,
			b.modds,
			0 AS OddsType,
			b.odds,
			'',
			b.status,
			0 AS SettlementStatus,
			'',
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.statusID NOT IN (0, 1) THEN (b.winlost - b.actual_stake)
				ELSE 0
			END AS WinLost,
			CASE WHEN b.statusID NOT IN (0, 1) THEN 
				CASE
					WHEN ISNULL(BA.transid,0) = 0 THEN - (b.winlost - b.actual_stake)
					ELSE 0
				END
			ELSE 0 END AS LicenseeWL,
			CASE WHEN b.statusID NOT IN (0,1) THEN b.comm ELSE 0 END AS comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			0,
			0,
			0,
			0,
			0,
			b.ip,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			0 AS OddsSpread
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) on b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) on m.leagueid = l.leagueid
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND b.bettype = 10
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Keno, Lottery, NPH Promotion, Virtual Games, Table Games, Indo 4D, Happy 5 Linked Games (bettrans)
		IF @TransType = 1 OR @TransType = 2
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN sbt.ProductId = 8 THEN 202
					WHEN sbt.ProductId = 28 THEN 220
					WHEN sbt.ProductId IN (3, 37, 38, 40, 43) THEN b.matchid
					ELSE 0
				END AS SportType,
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				b.bettype,
				'' AS matchcode,
				'' AS race,
				b.WinLostDate AS EventDate,
				0 AS matchid,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS betid,
				0 AS oddsid,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				0 AS Oddstype,
				CASE
					WHEN sbt.ProductID IN (8, 28, 38, 40, 43) THEN b.odds
					ELSE 0
				END AS Odds,
				'' AS betteam,
				CASE
					WHEN sbt.ProductID = 40 AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
					WHEN sbt.ProductID = 40 AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
					ELSE b.status
				END AS status,
				0 AS SettlementStatus,
				0 AS betstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductId = 8 THEN ISNULL(b.comstatus, '')
					WHEN sbt.ProductID IN (3, 38) THEN ISNULL(b.betcheck, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN sbt.ProductID IN (3, 8, 28, 38, 40, 43) THEN b.transdesc
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				CASE
					WHEN sbt.ProductID = 37 THEN ISNULL(b.ExtraInfo, '')
					ELSE ''
				END AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM 
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			WHERE
				b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND sbt.ProductID IN (3, 8, 28, 37, 38, 40, 43)
				AND sbt.EventType = 0
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END

		-- Keno, Colossus Bets, Lottery, Virtual Games, Table Games, Indo 4D, Happy 5 Linked Games (translog)
		IF @TransType = 3
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN sbt.ProductId = 8 THEN 202
					WHEN sbt.ProductId = 15 THEN 204
					WHEN sbt.ProductId = 28 THEN 220
					WHEN sbt.ProductId IN (3, 38, 40, 43) THEN t.productid
					ELSE 0
				END AS SportType,
				0 AS LeagueId,
				0 AS homeID,
				0 AS awayID,
				t.gameID AS BetType,
				'' AS matchcode,
				'' AS race,
				t.WinLostDate AS EventDate,
				0 AS matchid,
				t.translogid AS TransId,
				t.transdate,
				t.winlostdate,
				t.translogid AS RefNo,
				0 AS betid,
				0 AS oddsid,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS OddsType,
				CASE
					WHEN sbt.ProductID IN (8, 28, 38, 40, 43) THEN t.odds
					ELSE 0
				END AS Odds,
				'' AS betteam,
				t.status,
				0 AS SettlementStatus,
				0 AS betstatus,
				t.stake,
				t.actual_stake,
				0 AS WinLost,
				0 AS LicenseeWL,
				0 AS Comm,
				0 AS PlayerComm,
				t.discount,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS hthomescore,
				0 AS htawayscore,
				t.ip,
				t.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				t.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductId = 15 THEN t.Tranid3rd
					WHEN sbt.ProductId = 8 THEN ISNULL(t.custom2, '')
					WHEN sbt.ProductId IN (3, 38) THEN ISNULL(t.Gameid3rd, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN sbt.ProductID IN (3, 8, 28, 38, 40, 43) THEN t.transdesc
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
				dbo.translog AS t WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON t.gameID = sbt.bettype
			WHERE
				t.custid = @CustId
				AND t.statusID IN (0,1)
				AND t.winlostdate = @FromDate
				AND sbt.ProductID IN (3, 8, 15, 28, 38, 40, 43)
				AND t.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END

		-- RNG Casino Single Wallet, Macau Games, Fishing World, Pragmatic Casino, Card Club, Spadegaming, Saba.club, PG Soft, Joker
		IF @TransType = 1
		BEGIN
			IF @FromDate < @yesterday	-- not yesterday and today settled ticket
			BEGIN
				INSERT INTO @Data 
				SELECT
					CASE
						WHEN sbt.ProductID IN (6, 34, 36, 42, 55, 56) THEN b.matchid
						WHEN sbt.ProductID = 22 THEN 212
						WHEN sbt.ProductID = 24 THEN 219
						WHEN sbt.ProductID = 32 THEN 248
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeID,
					0 AS awayID,
					b.bettype,
					'' AS matchcode,
					'' AS race,
					b.WinLostDate AS EventDate,
					0 AS matchid,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					0 AS betid,
					0 AS oddsid,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS Oddstype,
					CASE
						WHEN sbt.ProductID = 32 THEN b.odds
						ELSE 0
					END AS Odds,
					'' AS betteam,
					b.status,
					0 AS SettlementStatus,
					0 AS betstatus,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					- (b.winlost - b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					b.discount,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.ip,
					b.Username,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS ShowTime,
					'' AS betcheck,
					b.transdesc,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS OriginalStake,
					0 AS OriginalBetType,
					0 AS WalletType,
					0 AS RefCode,
					CASE
						WHEN sbt.ProductID = 32 THEN ISNULL(b.oddsspread, 0)
						ELSE 0
					END AS OddsSpread
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				WHERE
					b.custid = @CustId
					AND b.winlostdate = @FromDate 
					AND (sbt.ProductID IN (22, 24, 32, 34, 36, 42, 55, 56)
						OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
					AND sbt.EventType = 0
					AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
			END
			ELSE	-- yesterday and today settled ticket
			BEGIN
				INSERT INTO @Data 
				SELECT
					CASE
						WHEN sbt.ProductID IN (6, 34, 36, 42, 55, 56) THEN b.matchid
						WHEN sbt.ProductID = 22 THEN 212
						WHEN sbt.ProductID = 24 THEN 219
						WHEN sbt.ProductID = 32 THEN 248
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeID,
					0 AS awayID,
					b.bettype,
					'' AS matchcode,
					'' AS race,
					b.WinLostDate AS EventDate,
					0 AS matchid,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					0 AS betid,
					0 AS oddsid,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS Oddstype,
					CASE
						WHEN sbt.ProductID = 32
							THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
						ELSE 0
					END AS Odds,
					'' AS betteam,
					CASE 
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					0 AS betstatus,
					SUM(brng.stake) AS Stake,
					SUM(brng.actual_stake) AS Actual_Stake,
					SUM(brng.winlost - brng.actual_stake) AS Winlost,
					SUM(- (brng.winlost - brng.actual_stake)) AS LicenseeWL,
					SUM(brng.comm) AS comm,
					SUM(brng.playercomm) AS playercomm,
					b.discount,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.ip,
					b.Username,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS ShowTime,
					'' AS betcheck,
					b.transdesc,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS OriginalStake,
					0 AS OriginalBetType,
					0 AS WalletType,
					0 AS RefCode,
					CASE
						WHEN sbt.ProductID = 32 THEN ISNULL(SUM(brng.BetStake), 0)
						ELSE 0
					END AS OddsSpread
				FROM 
					dbo.bettransRnG AS brng WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				WHERE
					b.custid = @CustId
					AND b.winlostdate = @FromDate 
					AND (sbt.ProductID IN (22, 24, 32, 34, 36, 42, 55, 56)
						OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
					AND sbt.EventType = 0
					AND brng.statusID NOT IN (0, 1)
				GROUP BY
					b.Bettype,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					b.discount,
					b.IP,
					b.Username,
					b.currency,
					b.matchid,
					b.transdesc,
					sbt.ProductID
			END
		END
		ELSE IF @TransType = 3
		BEGIN
			IF @FromDate BETWEEN @yesterday AND @today		-- yesterday and today running ticket
			BEGIN
				INSERT INTO @Data 
				SELECT
					CASE
						WHEN sbt.ProductID IN (6, 34, 36, 42, 55, 56) THEN b.matchid
						WHEN sbt.ProductID = 22 THEN 212
						WHEN sbt.ProductID = 24 THEN 219
						WHEN sbt.ProductID = 32 THEN 248
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeID,
					0 AS awayID,
					b.bettype,
					'' AS matchcode,
					'' AS race,
					b.WinLostDate AS EventDate,
					0 AS matchid,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					0 AS betid,
					0 AS oddsid,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS Oddstype,
					0 AS odds,
					'' AS betteam,
					'Running' AS status,
					0 AS SettlementStatus,
					0 AS betstatus,
					SUM(brng.stake) AS Stake,
					SUM(brng.actual_stake) AS Actual_Stake,
					0 AS Winlost,
					0 AS LicenseeWL,
					0 AS comm,
					0 AS playercomm,
					0 AS discount,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.ip,
					b.Username,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS ShowTime,
					'' AS betcheck,
					b.transdesc,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS OriginalStake,
					0 AS OriginalBetType,
					0 AS WalletType,
					0 AS RefCode,
					0 AS OddsSpread
				FROM 
					dbo.bettransRnG AS brng WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				WHERE
					b.custid = @CustId
					AND b.winlostdate = @FromDate 
					AND (sbt.ProductID IN (22, 24, 32, 34, 36, 42, 55, 56)
						OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
					AND sbt.EventType = 0
					AND brng.statusID IN (0, 1)
				GROUP BY
					b.Bettype,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					b.IP,
					b.Username,
					b.currency,
					b.matchid,
					b.transdesc,
					sbt.ProductID
			END
		END

		-- Colossus Bets
		IF @TransType IN (1, 2)
		BEGIN
			INSERT INTO @Data 
			SELECT
				204 AS SportType,
				0 AS LeagueId,
				0 AS HomeId,
				0 AS AwayId,
				b.bettype,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS MatchId,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS BetId,
				0 AS OddsId,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsYype,
				0 AS Odds,
				'' AS BetTeam,
				b.status,
				'' AS BetStatus,
				b.stake,
				0 AS SettlementStatus,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.custid = @CustId
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID = 15
				AND sbt.EventType = 0
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END
		ELSE IF @TransType = 3
		BEGIN
			INSERT INTO @Data 
			SELECT
				204 AS SportType,
				0 AS LeagueId,
				0 AS HomeId,
				0 AS AwayId,
				b.bettype,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS MatchId,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS BetId,
				0 AS OddsId,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsYype,
				0 AS Odds,
				'' AS BetTeam,
				b.status,
				0 AS SettlementStatus,
				'' AS BetStatus,
				b.stake,
				b.actual_stake,
				0 AS WinLost,
				0 AS LicenseeWL,
				0 AS comm,
				0 AS playercomm,
				b.discount,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.custid = @CustId
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID = 15
				AND sbt.EventType = 0
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END
		
		-- Grand Prize Jackpot Win
		IF @TransType = 4
		BEGIN
			-- Colossus Bets
			INSERT INTO @Data
			SELECT
				204 AS SportType,
				0 AS LeagueId,
				0 AS HomeId,
				0 AS AwayId,
				b.bettype,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS MatchId,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS BetId,
				0 AS OddsId,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				0 AS Odds,
				'' AS BetTeam,
				b.status,
				0 AS SettlementStatus,
				'' AS BetStatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				b.transdesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.custid = @CustId
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID = 15
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND EXISTS (	SELECT 1 
								FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
								WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
		END

		-- AG Casino, AllBet, SA Gaming, Sexy Gaming
		IF @TransType = 1
		BEGIN
			IF @FromDate < @yesterday	-- not yesterday and today settled ticket
			BEGIN
				INSERT INTO @Data 
				SELECT
					CASE
						WHEN sbt.ProductID = 11 THEN 250
						WHEN sbt.ProductID = 21 THEN 211
						WHEN sbt.ProductID IN (39, 45) THEN b.matchid
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeID,
					0 AS awayID,
					b.bettype,
					'' AS matchcode,
					'' AS race,
					b.WinLostDate AS EventDate,
					0 AS matchid,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					0 AS betid,
					0 AS oddsid,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS Oddstype,
					0 AS odds,
					'' AS betteam,
					b.status,
					0 AS SettlementStatus,
					0 AS betstatus,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					- (b.winlost - b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					b.discount,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.ip,
					b.Username,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS ShowTime,
					'' AS betcheck
					,'' AS transdesc,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS OriginalStake,
					0 AS OriginalBetType,
					0 AS WalletType,
					0 AS RefCode,
					0 AS OddsSpread
				FROM 
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				WHERE
					b.custid = @CustId
					AND b.winlostdate = @FromDate 
					AND sbt.ProductID IN (11, 21, 39, 45)
					AND sbt.EventType = 0
					AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
			END
			ELSE	-- yesterday and today settled ticket
			BEGIN
				INSERT INTO @Data 
				SELECT
					CASE
						WHEN sbt.ProductID = 11 THEN 250
						WHEN sbt.ProductID = 21 THEN 211
						WHEN sbt.ProductID IN (39, 45) THEN b.matchid
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeID,
					0 AS awayID,
					b.bettype,
					'' AS matchcode,
					'' AS race,
					b.WinLostDate AS EventDate,
					0 AS matchid,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					0 AS betid,
					0 AS oddsid,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS Oddstype,
					0 AS odds,
					'' AS betteam,
					CASE 
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					0 AS betstatus,
					SUM(blc.stake) AS Stake,
					SUM(blc.actual_stake) AS Actual_Stake,
					SUM(blc.winlost - blc.actual_stake) AS Winlost,
					SUM(- (blc.winlost - blc.actual_stake)) AS LicenseeWL,
					SUM(blc.comm) AS comm,
					SUM(blc.playercomm) AS playercomm,
					b.discount,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.ip,
					b.Username,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS ShowTime,
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
					dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				WHERE
					b.custid = @CustId
					AND b.winlostdate = @FromDate 
					AND sbt.ProductID IN (11, 21, 39, 45)
					AND sbt.EventType = 0
					AND blc.statusID NOT IN (0, 1)
				GROUP BY
					b.Bettype,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					b.discount,
					b.IP,
					b.Username,
					b.currency,
					sbt.ProductID,
					b.matchid
			END
		END
		ELSE IF @TransType = 3
		BEGIN
			IF @FromDate BETWEEN @yesterday AND @today		-- yesterday and today running ticket
			BEGIN
				INSERT INTO @Data 
				SELECT
					CASE
						WHEN sbt.ProductID = 11 THEN 250
						WHEN sbt.ProductID = 21 THEN 211
						WHEN sbt.ProductID IN (39, 45) THEN b.matchid
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeID,
					0 AS awayID,
					b.bettype,
					'' AS matchcode,
					'' AS race,
					b.WinLostDate AS EventDate,
					0 AS matchid,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					0 AS betid,
					0 AS oddsid,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS Oddstype,
					0 AS odds,
					'' AS betteam,
					'Running' AS status,
					0 AS SettlementStatus,
					0 AS betstatus,
					SUM(blc.stake) AS Stake,
					SUM(blc.actual_stake) AS Actual_Stake,
					0 AS Winlost,
					0 AS LicenseeWL,
					0 AS comm,
					0 AS playercomm,
					0 AS discount,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.ip,
					b.Username,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS ShowTime,
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
					dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				WHERE
					b.custid = @CustId
					AND b.winlostdate = @FromDate 
					AND sbt.ProductID IN (11, 21, 39, 45)
					AND sbt.EventType = 0
					AND blc.statusID IN (0, 1)
				GROUP BY
					b.Bettype,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					b.IP,
					b.Username,
					b.currency,
					sbt.ProductID,
					b.matchid
			END
		END

		-- Get more info for BetTrade tickets
		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType IN (901, 902))
		BEGIN
			UPDATE betList
			SET betList.Odds = originBetList.odds,
				betList.Stake = originBetList.Stake,
				betList.LiveHomeScore = originBetList.livehomescore,
				betList.LiveAwayScore = originBetList.liveawayscore,
				betList.Comm = CASE
									WHEN betList.BetType = 902 THEN commBetList.comm
									ELSE betList.comm
								END,
				betList.BetId = originBetList.Bettype
			FROM @Data AS betList
				INNER JOIN dbo.bettrans AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.transid
				LEFT JOIN @Data AS commBetList ON betList.RefNo = commBetList.RefNo AND commBetList.BetType = 903
			WHERE betList.Sporttype = 1 AND betList.BetType IN (901, 902)
		END

		-- Get more info for CashOut tickets
		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911)
		BEGIN
			UPDATE b
			SET b.Odds = ob.odds,
				b.LiveIndicator = ob.liveindicator,
				b.LiveHomeScore = ob.livehomescore,
				b.LiveAwayScore = ob.liveawayscore,
				b.OriginalBetType = ob.bettype,
				b.BetdaqId = ob.transid
			FROM @Data AS b
				INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
			WHERE b.BetType = 911
		END

		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912)
		BEGIN
			UPDATE b
			SET b.Odds = ob.odds,
				b.LiveIndicator = ob.liveindicator,
				b.LiveHomeScore = ob.livehomescore,
				b.LiveAwayScore = ob.liveawayscore,
				b.OriginalBetType = ob.bettype,
				b.BetdaqId = ob.transid,
				b.Stake = cob.stake,
				b.Comm = ISNULL(cb.Comm, 0)
			FROM @Data AS b
				INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
				INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
				LEFT JOIN @Data AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
			WHERE b.BetType = 912
		END

		DELETE @Data 
		WHERE Bettype IN (903, 913)
	END

	DELETE @Data
	WHERE Currency NOT IN (SELECT DISTINCT Currency FROM @TempAg)

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
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
		FROM @Data
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
			FROM @Data AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE @Data
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE @Data
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Get exchange rate
	DECLARE @Currency	INT,
		@ExRate			FLOAT

	SELECT @Currency = currency
	FROM dbo.Customer WITH (NOLOCK)
	WHERE custid = @CustId

	IF @FromDate > @Today
	BEGIN
		SELECT @ExRate = CASE
						WHEN @BaseCurrency = 'MYR' THEN e.MYR
						WHEN @BaseCurrency = 'USD' THEN e.USD
						WHEN @BaseCurrency = 'EUR' THEN e.EUR
						WHEN @BaseCurrency = 'CNY' THEN e.CNY
						WHEN @BaseCurrency = 'IDR' THEN e.IDR
						WHEN @BaseCurrency = 'GBP' THEN e.GBP
						WHEN @BaseCurrency = 'THB' THEN e.THB
						WHEN @BaseCurrency = 'INH' THEN e.INH
						ELSE 1
					END
		FROM dbo.Lrf_f_GetExchangeDaily(@Today, @Today) AS e
		WHERE e.ExchangeId = @Currency
	END
	ELSE
	BEGIN
		SELECT @ExRate = CASE
						WHEN @BaseCurrency = 'MYR' THEN e.MYR
						WHEN @BaseCurrency = 'USD' THEN e.USD
						WHEN @BaseCurrency = 'EUR' THEN e.EUR
						WHEN @BaseCurrency = 'CNY' THEN e.CNY
						WHEN @BaseCurrency = 'IDR' THEN e.IDR
						WHEN @BaseCurrency = 'GBP' THEN e.GBP
						WHEN @BaseCurrency = 'THB' THEN e.THB
						WHEN @BaseCurrency = 'INH' THEN e.INH
						ELSE 1
					END
		FROM dbo.Lrf_f_GetExchangeDaily(@FromDate, @FromDate) AS e
		WHERE e.ExchangeId = @Currency
	END

	SET @ExRate = ISNULL(@ExRate, 1)

	-- Return data
	SELECT
		@TotalRows 		= COUNT(TransId),
		@SumWinlost		= SUM(WinLost)		* @ExRate,
		@SumLicenseeWL	= SUM(LicenseeWL)	* @ExRate,
		@SumComm		= SUM(Comm)			* @ExRate,
		@SumPlayerComm	= SUM(PlayerComm)	* @ExRate
	FROM @Data

	SELECT
		a.SportType,
		a.LeagueId,
		a.HomeId,
		a.AwayId,
		a.BetType,
		a.MatchCode,
		a.Race,
		a.EventDate,
		a.MatchId,
		a.TransId,
		a.TransDate,
		a.WinLostDate,
		a.RefNo,
		a.BetId,
		a.OddsId,
		a.Hdp1,
		a.Hdp2,
		a.Modds,
		a.OddsType,
		a.Odds,
		a.BetTeam,
		a.Status,
		a.SettlementStatus,
		a.BetStatus,
		a.Stake * @ExRate AS Stake,
		a.Actual_Stake * @ExRate AS Actual_Stake,
		a.WinLost * @ExRate AS WinLost,
		a.LicenseeWL * @ExRate AS LicenseeWL,
		a.Comm * @ExRate AS Comm,
		a.PlayerComm * @ExRate AS PlayerComm,
		a.Discount,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.LiveIndicator,
		a.FinalHomeScore,
		a.FinalAwayScore,
		a.HtHomeScore,
		a.HtAwayScore,
		a.Ip,
		a.Username,
		a.IsNeutral,
		a.Currency,
		a.ShowTime,
		a.BetCheck,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.OriginalStake * @ExRate AS OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode,
		a.OddsSpread
	FROM
	(
		SELECT
			ROW_NUMBER() OVER(ORDER BY b.TransDate ASC) AS RowNum,
			b.*
		FROM @Data AS b
	) AS a
	WHERE a.RowNum BETWEEN (((@PageIndex - 1) * @PageSize) + 1) AND (@PageSize * @PageIndex)

	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10)
	);

	IF @FromDate <= @MoveBetsDay
	BEGIN
		-- Virtual Sports
		SELECT
			bm.refno,
			bm.odds,
			bm.stake * @ExRate AS Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam
		FROM dbo.bettransm14 AS bm WITH (NOLOCK, INDEX=IX_bettransm14)
			INNER JOIN @Data AS b ON bm.refno = b.RefNo
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
			AND sbtm.ProductID = 5
			AND sbtm.EventType = 3
	END
	ELSE
	BEGIN
		-- Virtual Sports
		SELECT
			bm.refno,
			bm.odds,
			bm.Stake * @ExRate AS Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.Betteam
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @Data AS b ON bm.refno = b.RefNo
			INNER JOIN @SportBettype sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
			AND sbtm.ProductID = 5
			AND sbtm.EventType = 3
	END

	SELECT DISTINCT * FROM @BettransDetail
	ORDER BY RefNo ASC, BetType ASC
END
GO


GRANT EXECUTE ON [dbo].[Lrf_BetList_SelByDayAll_Mem] TO [bodbLicenseeNet]
GO 
