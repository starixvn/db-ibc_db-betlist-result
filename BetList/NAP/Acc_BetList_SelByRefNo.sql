USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Acc_BetList_SelByRefNo]
	@UserId			BIGINT,
	@RefNo			BIGINT,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created by: 20121212@Elodie
	Task: Get tickets by RefNo (display in column RefNo in bet list)
	DB: DBACC.bodb02
	Original: Acc_BetsSelBetList_ByTransID_Advance
	
	Revisions:
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20130227@Elodie: Add Virtual HR product
		- 20130724@Elodie: Get winlostdate field
		- 20130726@Elodie: Define data for bettrans, bettrans14, bettrans_bk by winlostdate field
		- 20140907@Dom: [Redmine #22012] update VS Condition
		- 20141103@Dom: Apply sport bettype matrix
		- 20150415@Sophia: Support Betradar and revise code of Bettype matrix
		- 20150506@Tom: Support Gold Deluxe Product [#34847]
		- 20150506@Bobby: Add transdesc column for metric gaming bettypes (801-899)
		- 20150615@Edward: Support for BetTrade
		- 20150707@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150805@Bobby: 
			+ Dis-allow to get ticket detail by refno 
			+ remove checking product when selecting ticket's eventtype = 1 from bettrans_bk
		- 20150814@Bobby: Fix bug #41544 - Exclude CS, BG, GD, KN, MG, MGC tickets
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150826@Kos: Exclude Colossus Bet ticket
		- 20151008@Kos: Exclude AG Casino ticket
		- 20151008@Kos: Exclude Microgaming RNG Casino ticket
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151216@Kos: Exclude Cockfighting ticket [#Redmine: 48850]
		- 20160119@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160203@Kos: Support AllBet [#Redmine: 50257]
		- 20160609@Kos: Support search 3rd tickets in range bettrans and bettrans14 [#Redmine: 55051]
			+ Move SP from DBAGE to DBACC
			+ Don't support Bingo and P2P in bettrans and bettrans14 range anymore
			+ Apply SportBetTypeMatrix function
		- 20160623@Kos: Hide special sites from unauthorized users [#Redmine: 48948]
		- 20160804@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160810@Kos: Support NG2
		- 20161017@Kos: Support search all AllBet related tickets [#Redmine: 65802]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix --
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM bodb02.dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID <> 1 OR BetType <> 904

	DECLARE
		@TransId		BIGINT,
		@BetType		INT,
		@WinLostDate	SMALLDATETIME,
		@CustId			INT

	-- FROM translog
	SELECT TOP 1
		@TransId = b.translogid,
		@BetType = b.gameID,
		@WinLostDate = b.winlostdate,
		@CustId = b.custid
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.translogid = @RefNo
		AND b.statusID = 0
		AND ( sp.productid IN (8, 12, 13, 15, 19)
			OR sp.bettype BETWEEN 801 AND 899 )

	-- FROM bettrans (exclude Metric Gaming running ticket)
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP 1
			@TransId = b.transid,
			@BetType = b.bettype,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE
			( b.transid = @RefNo
				OR ( b.refno = @RefNo
					AND (sp.productid IN (6, 8, 12, 13, 15, 19) OR sp.bettype BETWEEN 801 AND 899) ) )
			AND (b.bettype NOT BETWEEN 801 AND 806 OR b.statusID NOT IN (0, 1))
	END

	-- FROM bettrans14
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1
			@TransId = b.transid,
			@BetType = b.bettype,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.transid = @RefNo
			OR ( b.refno = @RefNo
				AND (sp.productid IN (6, 8, 12, 13, 15, 19) OR sp.bettype BETWEEN 801 AND 899))
	END

	-- FROM bettrans_bk
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1
			@TransId = b.transid,
			@BetType = b.bettype,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.transid = @RefNo
	END

	DECLARE @Data TABLE (
		BetType				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				NVARCHAR(50),
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(20),
		EventDate			SMALLDATETIME,
		VirtualRate			FLOAT,
		IsShowOTExRate		BIT,
		SDiscount			SMALLMONEY,
		ADiscount			SMALLMONEY,
		Discount			SMALLMONEY,
		HomeId				INT,
		AwayId				INT,
		SettleTime			DATETIME,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		FinalOdds			MONEY,
		FinalOdds2			MONEY,
		OddsType			TINYINT,
		Status				NVARCHAR(50),
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(50),
		SPositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		APositionTaking		SMALLMONEY,
		SPositionTaking2	SMALLMONEY,
		MPositionTaking2	SMALLMONEY,
		APositionTaking2	SMALLMONEY,
		LiveIndicator		BIT,
		Modds				MONEY,
		CustId				INT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		LeagueId			INT,
		SportType			SMALLINT,
		Ip					NVARCHAR(15),
		BetFrom				NVARCHAR (1),
		MatchId				INT,
		IsNeutral			BIT,
		WinLost				MONEY,
		Commission			MONEY,
		SComm				MONEY,
		AComm				MONEY,
		Comm				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		ShowTime			NVARCHAR(50),
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		OddsSpread			SMALLMONEY
	)

	DECLARE @DetailData TABLE (
		RefNo			NVARCHAR(50),
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(50),
		APositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		SPositionTaking SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(50),
		TransDesc		VARCHAR(300)
	)

	DECLARE @DeniedSite TABLE (
		SiteId			INT,
		Site			NVARCHAR(50),
		SpecialGroup	TINYINT)

	DECLARE @Sql VARCHAR(500)

	SET @Sql = 'SELECT * 
				FROM OPENQUERY(DBPOLICY,
					''SELECT siteid, site, SpecialGroup
					FROM bodb02.dbo.f_GetDeniedSiteByUser( ''''' + CAST(@Userid AS VARCHAR(50)) + ''''')'')'

	INSERT INTO @DeniedSite
	EXEC (@Sql)

	IF @WinlostDate IS NOT NULL
		AND NOT EXISTS ( SELECT 1
						FROM dbo.customer AS c WITH (NOLOCK)
							INNER JOIN dbo.customer AS a WITH (NOLOCK) ON c.recommend = a.custid
							WHERE c.custid = @CustId
								AND a.site IN (SELECT Site FROM @DeniedSite))
	BEGIN
		-- Bettrans
		IF @WinlostDate > @MoveBetsDay
		BEGIN
			-- Sportbooks, Number Game, Live Casino, Virtual Sports (EventType = 1)
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE EventType = 1 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					m.matchcode,
					'' AS Race,
					m.eventdate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					CASE
						WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						ELSE b.status
					END AS status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					m.showtime,
					b.winlostdate,
					b.betcheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
				WHERE b.transid = @TransId AND s.EventType = 1

				UNION ALL -- translog metric gaming
				SELECT
					b.gameid AS BetType,
					b.translogid AS TransId,
					0 AS BetId,
					b.translogid AS RefNo,
					m.matchcode,
					'' AS Race,
					m.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					CASE
						WHEN b.gameid IN (801,803,804,805,806) THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
						ELSE 0
					END AS OddsType,
					b.status,
					'' AS comstatus,
					stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.eventID AS MatchId,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					0 AS winlost,
					0 AS Commission,
					0 AS scomm,
					0 AS acomm,
					0 AS comm,
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					m.showtime,
					b.winlostdate,
					'' AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					0 AS OddsSpread
				FROM dbo.translog AS b WITH (NOLOCK) 
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventId = m.matchid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.translogid = @TransId
					AND b.statusID IN (0, 1)
					AND s.BetType BETWEEN 801 AND 899

				UPDATE betList
				SET betList.Odds	= originBetList.Odds
					,betList.Stake	= originBetList.Stake
					,betList.comm	= CASE WHEN betList.Bettype = 902 THEN ISNULL(commBetList.awinlost,0) ELSE betList.comm END
					,betList.BetID	= originBetList.Bettype
				FROM @Data AS betList
					INNER JOIN dbo.bettrans AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.transid
					LEFT JOIN @Data AS commBetList ON betList.RefNo = commBetList.RefNo AND commBetList.BetType = 903
				WHERE betList.Sporttype = 1 AND betList.BetType IN (901, 902)
			END

			-- Mix Parlay, Combination Mix Parlay
			IF @BetType IN (9, 29)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					CASE
						WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
						ELSE b.transid
					END AS TransId,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS MatchCode,
					'' AS Race,
					'' AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS HomeId,
					0 AS AwayId,
					'' AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS LiveIndicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS LeagueId,
					0 AS SportType,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS SComm,
					(b.acomm - b.comm) AS AComm,
					(b.comm - b.playercomm) AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS ShowTime,
					b.winlostdate,
					b.betcheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
				WHERE b.transid = @TransId AND b.bettype IN (9, 29)
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					odds.matchcode,
					odds.groupmatch AS Race,
					odds.eventdate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS Homeid,
					odds.teamid AS awayid,
					'' AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					odds.leagueid,
					l.sporttype,
					b.ip ,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					 '' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.transid = @TransId AND b.bettype = 10
			END

			-- Horse Racing
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE ProductID = 2 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate,
					b.virtualrate,
					CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					odds.teamid AS homeid,
					0 AS awayid,
					'' AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					bm.finalodds,
					bm.finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					CASE WHEN b.bettype IN (33, 43) THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.apositiontaking2 ELSE 0 END,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					odds.leagueid,
					l.sporttype,
					b.ip ,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost-b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					 '' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							t.finalodds,
							f.apositiontaking AS APositionTaking2,
							f.mpositiontaking AS MPositionTaking2,
							f.spositiontaking AS SPositionTaking2,
							f.finalodds AS finalodds2
						FROM dbo.bettransm AS t WITH (NOLOCK)
							INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno 
						WHERE t.bettype IN (31, 41) AND f.bettype IN (32, 42)
					) bm ON b.transid = bm.refno
				WHERE b.transid = @TransId AND s.ProductID = 2
			END

			-- Casino, Gold Deluxe, Microgaming Live Casino, Cockfighting, NG2
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype
						WHERE BetType = @BetType
							AND (ProductID IN (12, 13, 19, 23)
								OR (ProductID = 6 AND SubProduct = '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					CASE
						WHEN s.ProductId = 23 THEN b.hdp1
						ELSE 0
					END AS hdp1,
					CASE
						WHEN s.ProductId = 23 THEN b.hdp2
						ELSE 0
					END AS hdp2,
					CASE
						WHEN s.ProductID IN (12, 19, 23) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					CASE
						WHEN s.ProductID = 19 THEN b.oddstype
						ELSE 0
					END AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					CASE
						WHEN s.ProductId = 23 THEN b.livehomescore
						ELSE 0
					END AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 6 THEN 251
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 13 THEN 203
						WHEN s.ProductID = 19 THEN 206
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					END AS SportType,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 12 THEN b.matchid
						WHEN s.ProductID IN (19, 23) THEN b.betdaqid
						ELSE 0
					END AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					CASE
						WHEN s.ProductID IN (12, 13, 19) THEN b.betcheck
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID IN (19, 23) THEN b.transdesc
						ELSE ''
					END AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId
					AND (s.ProductId IN (12, 13, 19, 23)
						OR (s.ProductId = 6 AND s.SubProduct = ''))
			END

			-- Keno
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype WHERE ProductID = 8 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					d.ChoiceId AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					0 AS leagueid,
					202 AS SportType,
					b.ip,
					b.betfrom,
					d.GameId AS matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) d
				WHERE b.transid = @TransId AND s.ProductID = 8
				UNION ALL	-- translog
				SELECT 
					b.gameid AS BetType,
					0 AS TransId,
					0 AS BetId,
					b.translogid,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0,
					0,
					sdiscount,
					adiscount,
					discount,
					0 AS homeid,
					0 AS awayid,
					'' settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					d.ChoiceId AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					202 AS SportType,
					b.ip,
					b.betfrom,
					d.GameId matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(-b.actual_stake) AS winlost,
					0 AS Commission,
					0,
					0,
					0,
					0,
					0,
					0,
					'' AS showtime,
					b.winlostdate,
					'' AS BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.translog AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
					OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.gameid) d
				WHERE b.translogid = @TransId
					AND b.statusID = 0
					AND s.ProductID = 8
			END

			-- Virtual HR
			IF EXISTS(SELECT TOP 1 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					o.RacerNum AS MatchCode,
					b.oddsid AS Race,
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					o.RacerID AS HomeId,
					0 AS awayID,
					'' AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 finalhomescore,
					0 finalawayscore,
					r.leagueid,
					r.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT (BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					r.EventTime AS showtime,
					b.winlostdate,
					b.BetCheck,
					 '' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK) 
					INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType 
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							f.apositiontaking AS APositionTaking2,
							f.mpositiontaking AS MPositionTaking2,
							f.spositiontaking AS spositiontaking2
						FROM dbo.bettransm AS t WITH (NOLOCK)
							INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype = 1231 AND f.bettype = 1232 
						) bm ON b.refno = bm.refno
				WHERE b.transid = @TransId
					AND s.ProductID = 5
					AND s.EventType = 3
			END

			-- Gold Deluxe, Microgaming Live Casino, Cockfighting, Colossus Bet (translog)
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE ProductID IN (12, 13, 15, 19) AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameid AS BetType,
					b.translogid AS TransId,
					0 AS BetId,
					b.translogid AS RefNo,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (12, 13, 19) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					CASE
						WHEN s.ProductID = 19 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
						ELSE 0
					END AS OddsType,
					b.status,
					0 AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 13 THEN 203
						WHEN s.ProductID = 15 THEN 204
						WHEN s.ProductID = 19 THEN 206
					END AS SportType,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 19 THEN b.Gameid3rd
						ELSE 0
					END AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(-b.actual_stake) AS winlost,
					0 AS Commission,
					0,
					0,
					0,
					0,
					0,
					0,
					'' AS showtime,
					b.winlostdate,
					CASE
						WHEN s.ProductID IN (12, 13) THEN b.GameID3rd
						WHEN s.ProductID = 15 THEN b.Tranid3rd
						WHEN s.ProductID = 19 THEN b.custom2
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID = 19 THEN b.transdesc
						ELSE ''
					END AS TransDesc,
					0 AS OddsSpread
				FROM dbo.translog AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.translogid = @TransId
					AND b.statusID = 0
					AND s.ProductID IN (12, 13, 15, 19)
			END

			-- Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge
			IF EXISTS (	SELECT TOP 1 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (17, 22) 
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				IF @WinlostDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- yesterday and today
				BEGIN
					-- Today running ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.BetID, 0) AS BetId,
						b.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(brng.sdiscount) AS sdiscount,
						AVG(brng.adiscount) AS adiscount,
						AVG(brng.discount) AS discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						'Running' AS Status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(brng.stake) AS stake,
						SUM(brng.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(brng.spositiontaking) AS spositiontaking,
						AVG(brng.mpositiontaking) AS mpositiontaking,
						AVG(brng.apositiontaking) AS apositiontaking,
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 6 THEN b.matchid
							WHEN s.ProductID = 17 THEN 205
							WHEN s.ProductID = 22 THEN 212
						END AS Sporttype,
						b.ip,
						b.betfrom,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS winlost,
						0 AS Commission,
						0 AS scomm,
						0 AS acomm,
						0 AS comm,
						0 AS awinlost,
						0 AS mwinlost,
						0 AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22) THEN b.transdesc
							ELSE ''
						END AS TransDesc,
						0 AS OddsSpread
					FROM dbo.bettransRnG AS brng WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND (s.ProductId IN (17, 22)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
						AND brng.statusid = 0
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.matchid,
						b.betfrom,
						b.comstatus,
						b.transdesc,
						s.ProductID

					-- Today settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetId,
						b.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(brng.sdiscount) AS sdiscount,
						AVG(brng.adiscount) AS adiscount,
						AVG(brng.discount) AS discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						'' OddsType,
						CASE 
							WHEN SUM(brng.winlost - brng.actual_stake) = 0 THEN 'Draw'
							WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
							WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
						END AS Status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(brng.stake) AS stake,
						SUM(brng.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(brng.spositiontaking) AS spositiontaking,
						AVG(brng.mpositiontaking) AS mpositiontaking,
						AVG(brng.apositiontaking) AS apositiontaking,
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 6 THEN b.matchid
							WHEN s.ProductID = 17 THEN 205
							WHEN s.ProductID = 22 THEN 212
						END AS Sporttype,
						b.ip,
						b.betfrom,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						SUM(brng.winlost - brng.actual_stake) AS winlost,
						SUM(brng.playercomm) AS Commission,
						SUM(brng.scomm - brng.acomm) AS scomm,
						SUM(brng.acomm - brng.comm) AS acomm,
						SUM(brng.comm - brng.playercomm) AS comm,
						SUM(brng.awinlost) AS awinlost,
						SUM(brng.mwinlost) AS mwinlost,
						SUM(brng.swinlost) AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22) THEN b.transdesc
							ELSE ''
						END AS TransDesc,
						0 AS OddsSpread
					FROM dbo.bettransRnG AS brng WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND (s.ProductId IN (17, 22)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
						AND brng.statusid <> 0
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.matchid,
						b.betfrom,
						b.comstatus,
						b.transdesc,
						s.ProductID
				END
				ELSE
				BEGIN
					-- Not today settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetId,
						b.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						b.status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS betteam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 6 THEN b.matchid
							WHEN s.ProductID = 17 THEN 205
							WHEN s.ProductID = 22 THEN 212
						END AS Sporttype,
						b.ip,
						b.betfrom,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						(b.winlost - b.actual_stake) AS winlost,
						b.playercomm AS Commission,
						(b.scomm - b.acomm) AS scomm,
						(b.acomm - b.comm) AS acomm,
						(b.comm - b.playercomm) AS comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22) THEN b.transdesc
							ELSE ''
						END AS TransDesc,
						0 AS OddsSpread
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND (s.ProductId IN (17, 22)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
				END
			END

			-- AG Casino, AllBet
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE ProductID IN (11, 21) AND Bettype = @BetType)
			BEGIN
				IF @WinlostDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- yesterday and today
				BEGIN
					-- Yesterday and today running ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.BetID, 0) AS BetId,
						b.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(blc.sdiscount) AS sdiscount,
						AVG(blc.adiscount) AS adiscount,
						AVG(blc.discount) AS discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						'Running' AS Status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(blc.stake) AS stake,
						SUM(blc.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(blc.spositiontaking) AS spositiontaking,
						AVG(blc.mpositiontaking) AS mpositiontaking,
						AVG(blc.apositiontaking) AS apositiontaking,
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
						END AS Sporttype,
						b.ip,
						b.betfrom,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS winlost,
						0 AS Commission,
						0 AS scomm,
						0 AS acomm,
						0 AS comm,
						0 AS awinlost,
						0 AS mwinlost,
						0 AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						'' AS TransDesc,
						0 AS OddsSpread
					FROM dbo.bettransLC AS blc WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND s.ProductID IN (11, 21)
						AND blc.statusID = 0
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.betfrom,
						b.comstatus,
						s.ProductID

					-- Yesterday and today settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetId,
						b.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(blc.sdiscount) AS sdiscount,
						AVG(blc.adiscount) AS adiscount,
						AVG(blc.discount) AS discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						CASE 
							WHEN SUM(blc.winlost - blc.actual_stake) = 0 THEN 'Draw'
							WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
							WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
						END AS Status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(blc.stake) AS stake,
						SUM(blc.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(blc.spositiontaking) AS spositiontaking,
						AVG(blc.mpositiontaking) AS mpositiontaking,
						AVG(blc.apositiontaking) AS apositiontaking,
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
						END AS Sporttype,
						b.ip,
						b.betfrom,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						SUM(blc.winlost - blc.actual_stake) AS winlost,
						SUM(blc.playercomm) AS Commission,
						SUM(blc.scomm - blc.acomm) AS scomm,
						SUM(blc.acomm - blc.comm) AS acomm,
						SUM(blc.comm - blc.playercomm) AS comm,
						SUM(blc.awinlost) AS awinlost,
						SUM(blc.mwinlost) AS mwinlost,
						SUM(blc.swinlost) AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						'' AS TransDesc,
						0 AS OddsSpread
					FROM dbo.bettransLC AS blc WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND s.ProductID IN (11, 21)
						AND blc.statusID <> 0
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.betfrom,
						b.comstatus,
						s.ProductID
				END
				ELSE
				BEGIN
					-- Not yesterday and today settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.BetID, 0) AS BetId,
						b.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						b.status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS betteam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
						END AS Sporttype,
						b.ip,
						b.betfrom,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						(b.winlost - b.actual_stake) AS winlost,
						b.playercomm AS Commission,
						(b.scomm - b.acomm) AS scomm,
						(b.acomm - b.comm) AS acomm,
						(b.comm - b.playercomm) AS comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						'' AS TransDesc,
						0 AS OddsSpread
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND s.ProductID IN (11, 21)
				END
			END

			-- Colossus Bet
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype WHERE ProductID = 15 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					204 AS SportType,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(bm.betcheck, '') AS BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
				WHERE b.transid = @TransId
					AND s.ProductID = 15
			END
		END

		-- Bettrans14
		ELSE IF @WinlostDate <= @MoveBetsDay AND @WinlostDate >= @BalanceUpDay
		BEGIN
			-- Sportbooks, Number Game, Live Casino, Virtual Sports
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE EventType = 1 AND BetType = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					m.matchcode,
					'' AS Race,
					m.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					m.showtime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE s.EventType = 1 AND b.transid = @TransId
			END

			UPDATE betList
			SET betList.Odds	= originBetList.Odds
				,betList.Stake	= originBetList.Stake
				,betList.comm	= CASE WHEN betList.Bettype = 902 THEN ISNULL(commBetList.awinlost,0) ELSE betList.comm END
				,betList.BetID	= originBetList.Bettype
			FROM @Data AS betList
				INNER JOIN dbo.bettrans14 AS originBetList WITH(NOLOCK) ON betList.RefNO = originBetList.TransID
				LEFT JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNO AND commBetList.Bettype = 903
			WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)

			-- Mix Parlay, Combination Mix Parlay
			IF @BetType IN (9, 29)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					CASE
						WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
						ELSE b.transid
					END AS TransId,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS MatchCode,
					'' AS Race,
					'' AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS HomeId,
					0 AS AwayId,
					'' AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS LiveIndicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS LeagueId,
					0 AS SportType,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS SComm,
					(b.acomm - b.comm) AS AComm,
					(b.comm - b.playercomm) AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS ShowTime,
					b.winlostdate,
					b.betcheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
				WHERE b.transid = @TransId AND b.bettype IN (9, 29)
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data
				SELECT 
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetId,
					b.refno,
					odds.matchcode, 
					odds.groupmatch AS race,
					odds.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					odds.teamid AS awayid,
					'' settleTime, 
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					odds.leagueid,
					l.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost-b.actual_stake)  winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.bettype = 10
					AND b.transid = @TransId
			END

			-- Horse Racing
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE ProductID = 2 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT 
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate,
					b.virtualrate,
					CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					odds.teamid AS homeid,
					0 AS awayid,
					'' settleTime, 
					b.hdp1,
					b.hdp2,
					b.odds,
					bm.finalodds,
					bm.finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake, 
					b.actual_stake,
					b.transdate,
					b.betteam,
					CASE WHEN b.bettype IN (33, 43) THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.apositiontaking2 ELSE 0 END,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					odds.leagueid,
					l.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost-b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
					INNER JOIN @SportBettype s ON s.BetType = b.BetType
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							t.finalodds,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2,
							f.finalodds finalodds2
						FROM dbo.bettransm14 AS t WITH (NOLOCK)
							INNER JOIN dbo.bettransm14 AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype IN (31,41) AND f.bettype IN (32,42)
					) bm ON b.transid = bm.refno 
				WHERE s.ProductID = 2 AND b.transid = @TransId
			END
		
			-- Virtual HR
			IF EXISTS(SELECT TOP 1 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT 
					b.bettype,
					b.transid,
					'' AS BetId,
					b.refno,
					o.RacerNum matchcode, --Horse Number
					b.oddsid AS Race, --Outright ID
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					o.RacerID AS homeID,
					0 AS awayID,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					stake,
					b.actual_stake,
					b.transdate,
					'' betteam, 
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore, 
					b.liveawayscore, 
					0 finalhomescore, 
					0 finalawayscore, 
					r.leagueid,
					r.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT (BIT, 0) AS IsNeutral,
					(b.winlost-b.actual_stake)  winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					r.EventTime showtime, -- Race Name
					b.winlostdate,
					b.BetCheck,
					 '' AS TransDesc,
					 0 AS OddsSpread
				FROM 
					dbo.bettrans14 AS b WITH (NOLOCK) 
					INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType 
					LEFT JOIN (
						SELECT 
							t.refno, 
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2
						FROM dbo.bettransm14 AS t WITH (NOLOCK)  
							INNER JOIN dbo.bettransm14 AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype = 1231 AND f.bettype = 1232 
						) bm ON b.refno = bm.refno
				WHERE b.transid = @TransId
					AND s.ProductID = 5
					AND s.EventType = 3
			END

			-- RNG Casino, Gold Deluxe, Microgaming Live Casino, Cockfighting
			-- Microgaming RNG Casino, AG Casino, AllBet, Voidbridge, NG2
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND ProductID IN (6, 11, 12, 13, 17, 19, 21, 22, 23))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					CASE
						WHEN s.ProductId = 23 THEN b.hdp1
						ELSE 0
					END AS hdp1,
					CASE
						WHEN s.ProductId = 23 THEN b.hdp2
						ELSE 0
					END AS hdp2,
					CASE
						WHEN s.ProductID IN (12, 19, 23) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					CASE
						WHEN s.ProductID = 19 THEN b.oddstype
						ELSE 0
					END AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					CASE
						WHEN s.ProductId = 23 THEN b.livehomescore
						ELSE 0
					END AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 6 AND SubProduct <> '' THEN b.matchid
						WHEN s.ProductID = 6 AND SubProduct = '' THEN 251
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 13 THEN 203
						WHEN s.ProductID = 17 THEN 205
						WHEN s.ProductID = 19 THEN 206
						WHEN s.ProductID = 21 THEN 211
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					END AS SportType,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 12 THEN b.matchid
						WHEN s.ProductID IN (19, 23) THEN b.betdaqid
						ELSE 0
					END AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					CASE
						WHEN s.ProductID IN (12, 13, 19) THEN b.betcheck
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID = 6 AND s.SubProduct <> '' THEN b.transdesc
						WHEN s.ProductID IN (19, 22, 23) THEN b.transdesc
						ELSE ''
					END AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransID
					AND s.ProductID IN (6, 11, 12, 13, 17, 19, 21, 22, 23)
			END

			-- Keno
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE ProductID = 8 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					sdiscount,
					adiscount,
					discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					d.ChoiceId betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0, 
					0,
					0 AS leagueid,
					202 AS SportType,
					b.ip,
					b.betfrom,
					d.GameId matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost-b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) d
				WHERE b.transid = @TransId
					AND b.statusID NOT IN (0,1)
					AND s.ProductID = 8
			END

			-- Colossus Bet
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE ProductID = 15 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					204 AS SportType,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate ,
					ISNULL(bm.betcheck, '') AS BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
				WHERE b.transid = @TransId
					AND s.ProductID = 15
			END
		END

		-- Bettrans_bk
		ELSE IF @WinlostDate < @BalanceUpDay
		BEGIN
			-- Sportbooks, Number Game, Live Casino, Virtual Sports
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE EventType = 1 AND BetType = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetId,
					b.refno,
					m.matchcode,
					'' AS Race,
					m.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					(b.winlost-b.actual_stake)  winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					m.showtime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread
				FROM
					bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype s ON s.BetType = b.BetType
				WHERE s.EventType = 1 AND b.transid = @TransId

				UPDATE betList
				SET betList.Odds	= originBetList.Odds
					,betList.Stake	= originBetList.Stake
					,betList.comm	= CASE WHEN betList.Bettype = 902 THEN ISNULL(commBetList.awinlost,0) ELSE betList.comm END
					,betList.BetID	= originBetList.Bettype
				FROM @Data AS betList
					INNER JOIN bodb_archive.dbo.bettrans_bk AS originBetList WITH(NOLOCK) ON betList.RefNO = originBetList.TransID
					LEFT JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNO AND commBetList.Bettype = 903
				WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)
			END

			-- Mix Parlay, Combination Mix Parlay
			IF @BetType IN (9, 29)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					CASE
						WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
						ELSE b.transid
					END AS TransId,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS MatchCode,
					'' AS Race,
					'' AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS HomeId,
					0 AS AwayId,
					'' AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS LiveIndicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS LeagueId,
					0 AS SportType,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS SComm,
					(b.acomm - b.comm) AS AComm,
					(b.comm - b.playercomm) AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS ShowTime,
					b.winlostdate,
					b.betcheck,
					'' AS TransDesc,
					0 AS bettrans14
				FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				WHERE b.transid = @TransId AND b.bettype IN (9, 29)
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetId,
					b.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					odds.teamid AS awayid,
					'' settleTime, 
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					odds.leagueid,
					l.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost-b.actual_stake)  winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN bodb_Archive.dbo.outright_bk AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.bettype = 10
					AND b.transid = @TransId
			END

			-- Horse Racing
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE ProductID = 2 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate,
					b.virtualrate,
					CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					odds.teamid AS homeid,
					0 AS awayid,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					bm.finalodds,
					bm.finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					CASE WHEN b.bettype IN (33, 43) THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype IN (33, 43) THEN bm.apositiontaking2 ELSE 0 END,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					odds.leagueid,
					l.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost-b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN bodb_Archive.dbo.outright_bk AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							t.finalodds,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2,
							f.finalodds finalodds2
						FROM bodb_Archive.dbo.bettransm AS t WITH (NOLOCK)
							INNER JOIN bodb_Archive.dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno 
						WHERE t.bettype IN (31,41) AND f.bettype IN (32,42)
					) bm ON b.transid = bm.refno 
				WHERE s.ProductID = 2 AND b.transid = @TransId
			END

			-- Virtual HR
			IF EXISTS(SELECT TOP 1 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT 
					b.bettype,
					b.transid,
					'' AS BetId,
					b.refno,
					o.RacerNum matchcode, --Horse Number
					b.oddsid AS Race, --Outright ID
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					o.RacerID AS homeID,
					0 AS awayID,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					stake,
					b.actual_stake,
					b.transdate,
					'' betteam, 
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore, 
					b.liveawayscore, 
					0 finalhomescore, 
					0 finalawayscore, 
					r.leagueid,
					r.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT (BIT, 0) AS IsNeutral,
					(b.winlost-b.actual_stake)  winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					r.EventTime showtime, -- Race Name
					b.winlostdate,
					b.BetCheck,
					 '' AS TransDesc,
					 0 AS OddsSpread
				FROM 
					bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK) 
					INNER JOIN bodb_archive.dbo.VSOutright_bk AS o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType
					LEFT JOIN (
						SELECT 
							t.refno, 
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2
						FROM bodb_archive.dbo.bettransm AS t WITH (NOLOCK)
							INNER JOIN bodb_archive.dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype = 1231 AND f.bettype = 1232 
						) bm ON b.refno = bm.refno
				WHERE b.transid = @TransId
					AND s.ProductID = 5
					AND s.EventType = 3
			END

			-- RNG Casino Single Wallet, Microgaming RNG Casino, AG Casino Single Wallet, AllBet, Voidbridge, NG2
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype
						WHERE Bettype = @BetType 
							AND (ProductID IN (11, 17, 21, 22, 23)
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					CASE
						WHEN s.ProductId = 23 THEN b.hdp1
						ELSE 0
					END AS hdp1,
					CASE
						WHEN s.ProductId = 23 THEN b.hdp2
						ELSE 0
					END AS hdp2,
					CASE
						WHEN s.ProductId = 23 THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					CASE
						WHEN s.ProductId = 23 THEN b.livehomescore
						ELSE 0
					END AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 6 AND SubProduct <> '' THEN b.matchid
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 17 THEN 205
						WHEN s.ProductID = 21 THEN 211
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					END AS SportType,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductId = 23 THEN b.betdaqid
						ELSE 0
					END AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID = 6 AND s.SubProduct <> '' THEN b.transdesc
						WHEN s.ProductID IN (22, 23) THEN b.transdesc
						ELSE ''
					END AS TransDesc,
					0 AS OddsSpread
				FROM bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransID
					AND (s.ProductID IN (11, 17, 21, 22, 23)
						OR (s.ProductID = 6 AND s.SubProduct <> ''))
			END
		END
	
		DELETE @Data WHERE sporttype = 1 AND bettype = 903
	END

	IF EXISTS (	SELECT TOP 1 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype 
				WHERE ProductID IN (4, 12))
	BEGIN
		IF @WinlostDate > @MoveBetsDay
		BEGIN
			INSERT INTO @DetailData
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.mpositiontaking,
				bg.spositiontaking,
				bg.bettype,
				bg.betteam,
				bg.TransDesc
			FROM dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN @SportBettype sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS B1 ON bg.refno = B1.refno AND bg.bettype = B1.bettype
			WHERE sp.Productid = 4

			UNION ALL

			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.mpositiontaking,
				bg.spositiontaking,
				bg.bettype,
				bg.betteam,
				bg.TransDesc
			FROM dbo.bettransg bg WITH (NOLOCK)
				INNER JOIN @SportBettype sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS B2 ON bg.refno = B2.transid AND bg.bettype = B2.bettype
			WHERE sp.Productid = 12
		END

		ELSE IF @WinlostDate <= @MoveBetsDay AND @WinlostDate >= @BalanceUpDay
		BEGIN
			INSERT INTO @DetailData
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.mpositiontaking,
				bg.spositiontaking,
				bg.bettype,
				bg.betteam,
				bg.TransDesc
			FROM dbo.bettransg14 AS bg WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS B1 ON bg.refno = B1.refno AND bg.bettype = B1.bettype
			WHERE sp.Productid = 4

			UNION ALL

			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.mpositiontaking,
				bg.spositiontaking,
				bg.bettype,
				bg.betteam,
				bg.TransDesc
			FROM dbo.bettransg14 AS bg WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS B2 ON bg.refno = B2.transid AND bg.bettype = B2.bettype
			WHERE sp.Productid = 12
		END
		ELSE
		BEGIN
			INSERT INTO @DetailData
			SELECT
				bg.refno,
				bg.odds, 
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.mpositiontaking,
				bg.spositiontaking,
				bg.bettype,
				bg.betteam,
				bg.TransDesc
			FROM bodb_Archive.dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS B1 ON bg.refno = B1.refno AND bg.bettype = B1.bettype
			WHERE sp.Productid = 4

			UNION ALL

			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.mpositiontaking,
				bg.spositiontaking,
				bg.bettype,
				bg.betteam,
				bg.TransDesc
			FROM bodb_Archive.dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS B2 ON bg.refno = B2.transid AND bg.bettype = B2.bettype
			WHERE sp.Productid = 12
		END
	END

	-- BettransRnG tables
	SET @WinlostDate = NULL
	SET @CustId = NULL

	-- bettransRnG
	SELECT TOP 1
		@TransId = b.transid,
		@BetType = b.gameID,
		@WinLostDate = b.winlostdate,
		@CustId = b.custid
	FROM dbo.bettransRnG AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.transid = @RefNo

	-- bettransRnG14
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1
			@TransId = b.transid,
			@BetType = b.gameID,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
		WHERE b.transid = @RefNo
	END

	IF @WinlostDate IS NOT NULL
		AND NOT EXISTS ( SELECT 1
						FROM dbo.customer AS c WITH (NOLOCK)
							INNER JOIN dbo.customer AS a WITH (NOLOCK) ON c.recommend = a.custid
							WHERE c.custid = @CustId
								AND a.site IN (SELECT Site FROM @DeniedSite))
	BEGIN
		-- bettransRnG
		IF @WinlostDate > @MoveBetsDay
		BEGIN
			-- Microgaming RNG Casino, RNG Casino Single Wallet, Macau Games
			IF EXISTS(	SELECT TOP 1 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (17, 22)
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread
				FROM dbo.bettransRnG AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND (s.ProductId IN (17, 22)
						OR (s.ProductId = 6 AND s.SubProduct <> ''))
			END
		END

		-- bettransRnG14
		ELSE IF @WinlostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- Microgaming RNG Casino, RNG Casino Single Wallet, Macau Games
			IF EXISTS(	SELECT TOP 1 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (17, 22)
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread
				FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND (s.ProductId IN (17, 22)
						OR (s.ProductId = 6 AND s.SubProduct <> ''))
			END
		END
	END

	-- BettransLC tables
	SET @WinlostDate = NULL
	SET @CustId = NULL

	-- bettransLC
	SELECT TOP 1
		@TransId = b.transid,
		@BetType = b.gameID,
		@WinLostDate = b.winlostdate,
		@CustId = b.custid
	FROM dbo.bettransLC AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.transid = @RefNo

	-- bettransLC14
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1
			@TransId = b.transid,
			@BetType = b.gameID,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.bettransLC14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
		WHERE b.transid = @RefNo
	END

	IF @WinlostDate IS NOT NULL
		AND NOT EXISTS ( SELECT 1
						FROM dbo.customer AS c WITH (NOLOCK)
							INNER JOIN dbo.customer AS a WITH (NOLOCK) ON c.recommend = a.custid
							WHERE c.custid = @CustId
								AND a.site IN (SELECT Site FROM @DeniedSite))
	BEGIN
		-- bettransLC
		IF @WinlostDate > @MoveBetsDay
		BEGIN
			-- AG Casino, AllBet
			IF EXISTS( SELECT TOP 1 1 FROM @SportBettype WHERE ProductID IN (11, 21) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE
						WHEN s.ProductID = 21 THEN b.GameId3rd
						ELSE ''
					END AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID = 21 THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread
				FROM dbo.bettransLC AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND s.ProductID IN (11, 21)
			END
		END

		-- bettransLC14
		ELSE IF @WinlostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- AG Casino, AllBet
			IF EXISTS( SELECT TOP 1 1 FROM @SportBettype WHERE ProductID IN (11, 21) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE
						WHEN s.ProductID = 21 THEN b.GameId3rd
						ELSE ''
					END AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID = 21 THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread
				FROM dbo.bettransLC14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND s.ProductID IN (11, 21)
			END
		END
	END

	-- Get AllBet related tickets (same game)
	IF @WinlostDate IS NOT NULL
		AND EXISTS (SELECT 1
					FROM @Data AS b
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE s.ProductID = 21 AND b.MatchCode <> '')
	BEGIN
		IF @WinlostDate > @MoveBetsDay
		BEGIN
			INSERT INTO @Data
			SELECT
				b.gameID AS BetType,
				b.transid,
				0 AS BetId,
				b.refno,
				CASE
					WHEN s.ProductID = 21 THEN b.GameId3rd
					ELSE ''
				END AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				CASE
					WHEN s.ProductID = 21 THEN b.odds
					ELSE 0
				END AS odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				b.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				b.productID AS Sporttype,
				b.ip,
				b.betfrom,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS Commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				0 AS OddsSpread
			FROM dbo.bettransLC AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.gameID = b1.BetType AND b.GameId3rd = b1.MatchCode
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
			WHERE s.ProductID = 21
				AND b1.MatchCode <> ''
				AND b.transid <> @TransId
		END

		-- bettransLC14
		ELSE IF @WinlostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			INSERT INTO @Data
			SELECT
				b.gameID AS BetType,
				b.transid,
				0 AS BetId,
				b.refno,
				CASE
					WHEN s.ProductID = 21 THEN b.GameId3rd
					ELSE ''
				END AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				CASE
					WHEN s.ProductID = 21 THEN b.odds
					ELSE 0
				END AS odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				b.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				b.productID AS Sporttype,
				b.ip,
				b.betfrom,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS Commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				0 AS OddsSpread
			FROM dbo.bettransLC14 AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.gameID = b1.BetType AND b.GameId3rd = b1.MatchCode
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
			WHERE s.ProductID = 21
				AND b1.MatchCode <> ''
				AND b.transid <> @TransId
		END
	END

	SELECT b.*,
		ci.username
	FROM @Data AS b
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON b.CustId = ci.custid
	ORDER BY b.TransId

	SELECT * FROM @DetailData
END




GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelByRefNo] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelByRefNo] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelByRefNo] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelByRefNo] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetList_SelByRefNo] TO [vnteam] 
