ALTER PROCEDURE [dbo].[Lrf_BetList_SelByDayAll_Mem_Old]
	@AgentList			VARCHAR(MAX),
	@CustId				INT,
	@FromDate			SMALLDATETIME,
	@TransType			TINYINT			= 0,
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumWinLostUSD		MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY			= 0 OUTPUT,
	@SumCommUSD			MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY			= 0 OUTPUT,
	@SumWinLostEUR		MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SumCommEUR			MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY			= 0 OUTPUT,
	@SumWinLostGBP		MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY			= 0 OUTPUT,
	@SumCommGBP			MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY			= 0 OUTPUT,
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT
AS

/*
	Created: Henry@20101210
	Task: Bet List for Daily Statement History
	DB: DBACC.bodb02
	Original: [Age_BetList_SelByDayAll_Mem_Old]

	Revisions:
		- 20110214@Jacob: Add column discount IN the result SET
		- 20110303@Henry: suppport based currency
		- 20110408@Amy: Change function to get Odds value AND odds type
		- 20110712@Henry: Add column LicenseeWL
		- 20110725@Henry: Get refund tickets
		- 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mix Parlay
		- 20110825@Henry: Add more bettype for euro site
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120319@Henry: show main transid for sub-ticket of system parlay
		- 20120724@Jim: add player commision value
		- 20120817@Jim: add Live Casino
		- 20120913@Jim: add Virtual Sport
		- 20130123@Daniel: Change link server alias
		- 20130410@Jim: return betteam,modd value for Parlay ticket (Mix parlay & system parlay)
		- 20130411@Jim: support base currency USD
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130905@Jim: support VHR
		- 20140310@Hannah: offer Keno
		- 20140324@Daniel: fix show RNG Casino / Bingo bets due to matchid = 0
		- 20140411@Francis: fix incorrect sporttypes showing for VHR, Racing
		- 20140411@Francis: add bettype restriction for VHR
		- 20150130@Winnie: Add base currency GBP
		- 20150413@Bobby: Re-format code & #32844 new 60 bettypes - betradar phase 2
		- 20150511@Kiwi: Fixed the bug (RedmineID: #35562)
		- 20150608@Edward: Support Microgaming
		- 20150729@Edward: Return betcheck for Microgaming
		- 20150923@Kos: Support AG Casino
		- 20151029@Kos: Change ProductId, SportType of Microgaming RNG Casino
		- 20151124@Kos: Support Microgaming RNG Casino Jackpot Grand Prize ticket
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151228@Kos: Support RNG Casino Single Wallet
		- 20160202@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160406@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160413@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160718@Kos: Remove Bingo and change to use inline function for SportBettypeMatrix
		- 20160727@Kos: Support AllBet [#Redmine: 61066]
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160915@Kos: Support Colossus Bets [#Redmine: 63785]
		- 20161007@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20161114@Kos: Support Fishing World [#Redmine: 66737]
		- 20170303@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20170330@Kos: Support CashOut [#Redmine: 71963]
		- 20170605@Kos: Get liveindicator from original ticket for 911 and 912 tickets [#Redmine: 77669]
		- 20170612@Kos: Seperate @TransType param value into 1 & 2 [#Redmine: 78117]
		- 20170622@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170628@Kos: Hotfix - CashOut Details link in Racing tickets [#Redmine: 79076]
		- 20170724@Kos: Support Keno Lottery [#Redmine: 79997]
		- 20170830@Kos: Support Licensee Bonus System [#Redmine: 72792]

	Param's Explanation:
		+ @TransType:
			1: Won/Lose/Draw/Refund ticket
			2: Void/Reject ticket
			4: Grand Prize ticket (Microgaming RNG Casino)
*/

BEGIN
	SET NOCOUNT ON;

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

	DECLARE @Username NVARCHAR(50)

	SELECT @Username = username
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE custid = @CustId
		AND currency IN (SELECT DISTINCT Currency FROM @TempAg)
	
	IF @Username IS NULL
	BEGIN
		SELECT @ErrCode = 101
			, @ErrMsg = 'Account was not found.'

		RETURN
	END

	/*
		Won: 112, Lose: 113, Draw: 111, Refund: 103
		Void: 102, Reject: 101
	*/
	DECLARE @TmpStatus TABLE (StatusId INT)

	IF @TransType = 1
	BEGIN
		INSERT INTO @TmpStatus
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 103
	END
	ELSE IF @TransType = 2
	BEGIN
		INSERT INTO @TmpStatus
		SELECT 101 UNION ALL
		SELECT 102
	END
	ELSE IF @TransType = 4
	BEGIN
		INSERT INTO @TmpStatus
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113
	END

	DECLARE @Data TABLE (
		SportType		INT,
		LeagueId		INT,
		HomeId			INT,
		AwayId			INT,
		BetType			SMALLINT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(50),
		MatchId			INT,
		TransId			BIGINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		RefNo			NVARCHAR(50),
		BetId			BIGINT,
		OddsId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		BetTeam			NVARCHAR(50),
		Status			NVARCHAR(50),
		BetStatus		NVARCHAR(50),
		Stake			MONEY, 
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	BIT,
		FinalHomeScore	SMALLINT,
		FinalAwayScore	SMALLINT,
		HtHomeScore		SMALLINT,
		HtAwayScore		SMALLINT,
		Ip				NVARCHAR(20),
		Username		NVARCHAR(50),
		IsNeutral		BIT,
		Currency		SMALLINT,
		ShowTime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		WalletType		TINYINT,
		RefCode			BIGINT
	)

	-- Get SportBetTypeMatrix
	DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID <= 6 OR ProductID IN (8, 11, 13, 15, 17, 21, 22, 24, 25, 27, 28)

	DELETE @SportBettype
	WHERE Bettype IN (904, 914)

	IF @TransType = 4	-- support only for Microgaming RNG Casino, Colossus Bets
	BEGIN
		DELETE @SportBettype
		WHERE ProductID NOT IN (15, 17)
	END
	-- end filer bettypes by sporttype

	-- Use temp variable to avoid using index in winlostdate column
	DECLARE @TempFromDate	SMALLDATETIME

	SET @TempFromDate = @FromDate
	
	IF @TransType IN (1, 2)
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
			b.Oddstype,
			b.odds,
			b.betteam,
			b.status,
			m.betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			CASE
				WHEN ba.transid IS NULL THEN - (b.winlost - b.actual_stake)
				ELSE 0
			END AS LicenseeWL,
			CASE
				WHEN b.bettype IN (903, 913) THEN b.awinlost
				ELSE b.comm
			END AS Comm,
			b.playercomm,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.finalhomescore,
			m.finalawayscore,
			m.hthomescore,
			m.htawayscore,
			b.ip,
			@Username,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency,
			CASE 
				WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime, '')
				WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE '' 
			END AS ShowTime,
			CASE 
				WHEN sbt.ProductID = 1 AND b.bettype IN (216, 217) THEN b.betcheck
				ELSE ''
			END AS betcheck,
			CASE 
				WHEN sbt.ProductID IN (1, 27) THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS transdesc,
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
			END AS RefCode
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction AS ba WITH (NOLOCK) ON b.transid = ba.transid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate = @TempFromDate
			AND b.statusID IN (SELECT StatusId FROM @TmpStatus)
			AND sbt.EventType = 1

		-- Get more info for BetTrade tickets
		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType IN (901, 902))
		BEGIN
			UPDATE betList
			SET betList.Odds = originBetList.odds,
				betList.Stake = originBetList.stake,
				betList.Comm = CASE
									WHEN betList.BetType = 902 THEN ISNULL(commBetList.comm, 0)
									ELSE betList.comm
								END,
				betList.BetId = originBetList.bettype
			FROM @Data AS betList
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.transid
				LEFT JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNo AND commBetList.BetType = 903
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
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
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
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
				LEFT JOIN @Data AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
			WHERE b.BetType = 912
		END

		DELETE @Data WHERE BetType IN (903, 913)


		-- Virtual Horse Racing
		INSERT INTO @Data
		SELECT
			r.sporttype,
			r.leagueid,
			o.RacerID AS homeID,
			0 awayID,
			b.bettype,
			CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
			'' AS race,
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
			b.oddstype,
			b.odds,
			b.betteam,
			b.status,
			r.betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			 - (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			0 AS FinalHomeScore,
			0 AS FinalAwayScore,
			0 AS hthomescore,
			0 AS htawayscore,
			b.ip,
			@Username,
			CONVERT(BIT, 0) AS IsNeutral,
			b.currency,
			CONVERT(VARCHAR(20),r.eventTime) AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			INNER JOIN bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate = @TempFromDate
			AND b.statusID IN (SELECT StatusId FROM @TmpStatus)
			AND sbt.ProductId = 5
			AND sbt.EventType = 3

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
			'' betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			CASE
				WHEN ba.transid IS NULL THEN - (b.winlost - b.actual_stake)
				ELSE 0
			END AS LicenseeWL,
			b.comm,
			b.playercomm,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			b.ip,
			@Username,
			CONVERT(BIT, 0) AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode
		FROM
			bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction AS ba WITH (NOLOCK) ON b.transid = ba.transid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate = @TempFromDate
			AND b.matchid IN (0, 9, 29, 2799) -- Should not remove 0 for Archive
			AND b.statusID IN (SELECT StatusId FROM @TmpStatus)
			AND sbt.ProductID IN (1, 27)
			AND sbt.EventType = 0

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
			'', 
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			CASE
				WHEN ISNULL(ba.transid, 0) = 0 AND b.bettype = 10 THEN - (b.winlost-b.actual_stake)
				WHEN b.bettype IN (31, 32, 33) THEN b.awinlost
				ELSE 0
			END AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.livehomescore,
			b.liveawayscore,
			0,
			0,
			0,
			0,
			0,
			b.ip,
			@Username,
			CONVERT(BIT,0) AS IsNeutral,
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
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			INNER JOIN bodb_archive.dbo.outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction AS ba WITH (NOLOCK) ON b.transid = ba.transid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate = @TempFromDate
			AND b.statusID IN (SELECT StatusId FROM @TmpStatus)
			AND sbt.ProductID IN (1, 2)
			AND sbt.EventType = 2

		-- RNG Casino, Keno, AG Casino, Microgaming Live Casino, Microgaming RNG Casino, AllBet, Macau Games, Fishing World
		-- Lottery
		INSERT INTO @Data
		SELECT
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN 251
				WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
				WHEN sbt.ProductID = 8 THEN 202
				WHEN sbt.ProductID = 11 THEN 250
				WHEN sbt.ProductID = 13 THEN 203
				WHEN sbt.ProductID = 17 THEN 205
				WHEN sbt.ProductID = 21 THEN 211
				WHEN sbt.ProductID = 22 THEN 212
				WHEN sbt.ProductID = 24 THEN 219
				WHEN sbt.ProductID = 28 THEN 220
				ELSE 0
			END AS SportType,
			0 AS leagueid,
			0 AS homeID,
			0 AS awayID,
			b.bettype,
			'' AS MatchCode,
			'' AS race,
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
				WHEN sbt.ProductID IN (8, 28) THEN b.Odds
				ELSE 0
			END AS Odds,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Betteam
				ELSE ''
			END AS BetTeam,
			b.status,
			'' AS BetStatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.livehomescore
				ELSE 0
			END AS LiveHomeScore,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.liveawayscore
				ELSE 0
			END AS LiveAwayScore,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.liveindicator
				ELSE 0
			END AS LiveIndicator,
			0 AS FinalHomeScore,
			0 AS FinalAwayScore,
			0 AS hthomescore,
			0 AS htawayscore,
			b.ip,
			@Username,
			CONVERT(BIT, 0) AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			CASE
				WHEN sbt.ProductID = 13 THEN b.betcheck
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
				WHEN sbt.ProductID IN (8, 22, 24, 28) THEN b.transdesc
				ELSE ''
			END AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode
		FROM bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate = @TempFromDate
			AND b.statusID IN (SELECT StatusId FROM @TmpStatus)
			AND sbt.ProductID IN (6, 8, 11, 13, 17, 21, 22, 24, 28)
			AND sbt.EventType = 0

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
			'' AS BetStatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			0 AS LicenseeWL,
			b.comm,
			b.playercomm,
			0 AS LiveHomeScore,
			0 AS LiveAwayScore,
			0 AS LiveIndicator,
			0 AS FinalHomeScore,
			0 AS FinalAwayScore,
			0 AS HtHomeScore,
			0 AS HtAwayScore,
			b.ip,
			@Username,
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
			0 AS RefCode
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
		WHERE b.custid = @CustId
			AND b.winlostdate = @TempFromDate
			AND b.statusID IN (SELECT StatusId FROM @TmpStatus)
			AND sbt.ProductID = 15
	END
	ELSE IF @transtype = 4		-- Grand Prize Jackpot Win
	BEGIN
		-- Microgaming RNG Casino
		INSERT INTO @Data
		SELECT
			205 AS SportType,
			0 AS LeagueId,
			0 AS HomeId,
			0 AS AwayId,
			b.gameID AS BetType,
			'' AS MatchCode,
			'' AS Race,
			0 AS MatchId,
			b.transid,
			pt.transdate,
			pt.winlostdate,
			b.refno,
			0 AS BetId,
			0 AS OddsId,
			0 AS hdp1,
			0 AS hdp2,
			0 AS modds,
			0 AS Oddstype,
			0 AS Odds,
			'' AS BetTeam,
			b.status,
			'' AS BetStatus,
			b.stake,
			b.actual_stake,
			pt.WinAmount AS WinLost,
			0 AS LicenseeWL,
			0 AS Comm,
			0 AS PlayerComm,
			0 AS LiveHomeScore,
			0 AS LiveAwayScore,
			0 AS LiveIndicator,
			0 AS FinalHomeScore,
			0 AS FinalAwayScore,
			0 AS hthomescore,
			0 AS htawayscore,
			b.ip,
			@Username,
			CONVERT(BIT, 0) AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			b.TranId3rd AS BetCheck,
			b.transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode
		FROM
			dbo.PayoutTrans AS pt WITH (NOLOCK)
			INNER JOIN bodb_Archive.dbo.bettransRnG_bk AS b WITH (NOLOCK) ON pt.RefNo = b.transid
			INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.bettype
		WHERE pt.custid = @CustId
			AND pt.winlostdate = @TempFromDate
			AND sbt.ProductID = 17
			AND b.statusID IN (SELECT StatusId FROM @TmpStatus)

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
			'' AS BetStatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			0 AS LicenseeWL,
			b.comm,
			b.playercomm,
			0 AS LiveHomeScore,
			0 AS LiveAwayScore,
			0 AS LiveIndicator,
			0 AS FinalHomeScore,
			0 AS FinalAwayScore,
			0 AS HtHomeScore,
			0 AS HtAwayScore,
			b.ip,
			@Username,
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
			0 AS RefCode
		FROM
			bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
		WHERE
			b.custid = @CustId
			AND b.winlostdate = @TempFromDate
			AND b.statusID IN (SELECT StatusId FROM @TmpStatus)
			AND sbt.ProductID = 15
			AND EXISTS (	SELECT 1 
							FROM dbo.PayoutTrans AS pt WITH (NOLOCK)
							WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
	END

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

	SELECT *
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @FromDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM @Data)

	SELECT
		@TotalRows			= COUNT(b.TransId),
		@SumWinLost			= SUM(ISNULL(b.WinLost, 0)),
		@SumLicenseeWL		= SUM(ISNULL(b.LicenseeWL, 0)),
		@SumComm			= SUM(ISNULL(b.Comm, 0)),
		@SumPlayerComm		= SUM(ISNULL(b.PlayerComm, 0)),
		-- USD
		@SumWinLostUSD		= SUM(ISNULL(b.WinLost		* e.USD, 0)),
		@SumLicenseeWLUSD	= SUM(ISNULL(b.LicenseeWL	* e.USD, 0)),
		@SumCommUSD			= SUM(ISNULL(b.Comm			* e.USD, 0)),
		@SumPlayerCommUSD	= SUM(ISNULL(b.PlayerComm	* e.USD, 0)),
		-- EUR
		@SumWinLostEUR		= SUM(ISNULL(b.WinLost		* e.EUR, 0)),
		@SumLicenseeWLEUR	= SUM(ISNULL(b.LicenseeWL	* e.EUR, 0)),
		@SumCommEUR			= SUM(ISNULL(b.Comm			* e.EUR, 0)),
		@SumPlayerCommEUR	= SUM(ISNULL(b.PlayerComm	* e.EUR, 0)),
		-- GBP
		@SumWinLostGBP		= SUM(ISNULL(b.WinLost		* e.GBP, 0)),
		@SumLicenseeWLGBP	= SUM(ISNULL(b.LicenseeWL	* e.GBP, 0)),
		@SumCommGBP			= SUM(ISNULL(b.Comm			* e.GBP, 0)),
		@SumPlayerCommGBP	= SUM(ISNULL(b.PlayerComm	* e.GBP, 0))
	FROM @Data AS b
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency

	SELECT A.* 
	FROM (
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.TransId, b.RefNo) AS RowNum,
				b.*,
				-- USD
				b.Stake			* e.USD AS StakeUSD,
				b.Actual_stake	* e.USD AS Actual_StakeUSD,
				b.WinLost		* e.USD AS WinLostUSD,
				b.LicenseeWL	* e.USD AS LicenseeWLUSD,
				b.Comm			* e.USD AS CommUSD,
				b.PlayerComm	* e.USD AS PlayerCommUSD,
				b.OriginalStake	* e.USD AS OriginalStakeUSD,
				-- EUR
				b.Stake			* e.EUR AS StakeEUR,
				b.Actual_stake	* e.EUR AS Actual_StakeEUR,
				b.WinLost		* e.EUR AS WinLostEUR,
				b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
				b.Comm			* e.EUR AS CommEUR,
				b.PlayerComm	* e.EUR AS PlayercommEUR,
				b.OriginalStake	* e.EUR AS OriginalStakeEUR,
				-- GBP
				b.Stake			* e.GBP AS StakeGBP,
				b.Actual_stake	* e.GBP AS Actual_StakeGBP,
				b.WinLost		* e.GBP AS WinLostGBP,
				b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
				b.Comm			* e.GBP AS CommGBP,
				b.PlayerComm	* e.GBP AS PlayerCommGBP,
				b.OriginalStake	* e.GBP AS OriginalStakeGBP
			FROM @Data AS b
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		) AS A
	WHERE A.RowNum BETWEEN (((@PageIndex - 1) * @PageSize) + 1) AND (@PageSize * @PageIndex)

	-- Get sub tickets
	DECLARE @BettransDetail TABLE(
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
	IF EXISTS (	SELECT 1
				FROM @Data AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
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
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @Data AS b ON bm.refno = b.TransId
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductID = 2
			AND sbtm.ProductID = 2
	END

	-- Live Casino
	IF EXISTS (	SELECT 1
				FROM @Data AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				WHERE sbt.ProductId = 4 )
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
			bg.stake * e.EUR,
			bg.stake * e.USD,
			bg.stake * e.GBP
		FROM bodb_Archive.dbo.bettransG AS bg WITH (NOLOCK)
			INNER JOIN @Data AS b ON bg.refno = b.RefNo
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
		WHERE bg.custid = @CustId
			AND sbt.ProductID = 4
			AND sbtg.ProductID = 4
	END

	-- Virtual Sports
	IF EXISTS (	SELECT 1
				FROM @Data AS b
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE sbt.ProductId = 5 AND sbt.EventType = 3)
	BEGIN
		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM bodb_Archive.dbo.bettransm AS bm with (NOLOCK)
			INNER JOIN @Data b ON bm.refno = b.RefNo
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
			AND sbtm.ProductID = 5
			AND sbtm.EventType = 3
	END

	SELECT * FROM @BettransDetail
	ORDER BY RefNo, BetType

	DROP TABLE #TempExchange
END









GO 
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelByDayAll_Mem_Old] TO [vnteam]
GO 
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelByDayAll_Mem_Old] TO [bodbLicenseeNet]
GO
