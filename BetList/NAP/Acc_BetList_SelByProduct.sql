/*<info serverAlias="DBAGE-BODB02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_SelByProduct]
	@UserId			BIGINT,
	@ProductId		TINYINT,
	@CustId			INT				= 0,
	@Username		NVARCHAR(50)	= '',
	@GameId			VARCHAR(100)	= '',
	@BetId			VARCHAR(100)	= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@Permission		VARCHAR(20)		= '1,2,3'
AS

/*
	Created by: 20160609@Kos
	Task: Search tickets by product
	DB: DBAGE.bodb02
	Original:
	
	Parameter Explanantion
		- @Permission
			- 1: Credit sites
			- 2: Deposit sites
			- 3: CN88
	
	Revisions:
		- 20160623@Kos: Hide special sites from unauthorized users [#Redmine: 48948]
		- 20160906@Kos: Support AllBet [#Redmine: 61876]
		- 20161202@Kos: Support Fishing World [#Redmine: 65934]
		- 20171025@Kos: Support Bullfighting [#Redmine: 84961]
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
		- 20180405@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20180515@Kos: Add Match No for Bullfighting [#Redmine: 84961]
		- 20180709@Kos: Support Poker Games [#Redmine: 97565]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20180927@Kos: Add new permission to view Licensee account [#Redmine: 96118]
		- 20181115@Kos: Hotfix - Bullfighting [#Redmine: 104833]
		- 20190321@Kos: Support Pragmatic Promotion Prize [#Redmine: 108117]
		- 20190531@Kos: Add new input param @Permission VARCHAR(20) [#Redmine: 114125]
					- Remove param @SiteType
		- 20190611@Kos: Support Card Club [#Redmine: 107645]
					- Don't support Poker Games anymore
		- 20190829@Kos: Don't support inactive products anymore [Redmine: #119100]
		- 20191029@Kos: Support Spadegaming [Redmine: #122140]
		- 20191218@Kos: Support Virtual Games [Redmine: #124759]
		- 20200222@Kos: Support SA Gaming [Redmine: #128048]
		- 20200324@Kos: Support Sexy Gaming [Redmine: #130680]
		- 20200331@Kos: Support Saba.club [Redmine: #130769]
		- 20200421@Kos: Support IBCBet Live Casino [Redmine: #130688]
		- 20200514@Kos: Support BBIN [Redmine: #131362]
		- 20200525@Kos: Support ION [Redmine: #132329]
		- 20200709@Kos: Support PP Jackpot [Redmine: #137284]
					- Return additional column BetdaqId BIGINT
		- 20200731@Kos: Support Saba.club Result [Redmine: #137680]
		- 20200808@Kos: Support PG Soft [Redmine: #137769]
		- 20200919@Kos: Support Joker [Redmine: #137942]
		- 20200930@Kos: Support GameId3rd for PG Soft [Redmine: #137769]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix --
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (@ProductId, 0, 0, 2, '', '', @IsTest)

	-- Get CustId if @CustId IS NULL
	IF @CustId IS NULL OR @CustId = 0
	BEGIN
		SELECT @CustId = custid
		FROM dbo.custInfo WITH (NOLOCK)
		WHERE username = @Username
	END

	DECLARE @Data TABLE (
		BetType			INT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			NVARCHAR(50),
		MatchCode		NVARCHAR(1000),
		SDiscount		SMALLMONEY,
		ADiscount		SMALLMONEY,
		Discount		SMALLMONEY,
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		OddsType		TINYINT,
		Status			NVARCHAR(50),
		ComStatus		NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(50),
		SPositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		APositionTaking	SMALLMONEY,
		LiveIndicator	BIT,
		CustId			INT,
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		LeagueId		INT,
		SportType		SMALLINT,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR (1),
		MatchId			INT,
		WinLost			MONEY,
		Commission		MONEY,
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		WinLostDate		SMALLDATETIME,
		BetCheck		NVARCHAR(2000),
		TransDesc		NVARCHAR(1000),
		OddsSpread		SMALLMONEY,
		ExtraInfo		VARCHAR(1000),
		BetdaqId		BIGINT
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
		TransDesc		VARCHAR(2000)
	)

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	DECLARE @DeniedSite TABLE (
		SiteId			INT,
		Site			NVARCHAR(50),
		SpecialGroup	TINYINT)

	DECLARE @Sql VARCHAR(500)

	SET @Sql = 'SELECT * 
				FROM OPENQUERY(DBPOL,
					''SELECT siteid, site, SpecialGroup
					FROM NAP_UserControl.dbo.f_GetDeniedSiteByUser( ''''' + CAST(@UserId AS VARCHAR(50)) + ''''')'')'

	INSERT INTO @DeniedSite
	EXEC (@Sql)

	INSERT INTO @DeniedSite (SiteId, Site, SpecialGroup)
	SELECT
		s.siteid,
		s.site,
		s.SpecialGroup
	FROM dbo.Site AS s WITH (NOLOCK)
	WHERE NOT EXISTS (SELECT 1 FROM @DeniedSite WHERE SiteId = s.siteid)
		AND ((s.isLicensee = 0									-- Don't have Credit sites permission
				AND s.site <> 'cn88'
				AND ',' + @Permission + ',' NOT LIKE '%,1,%')
			OR (s.isLicensee = 1								-- Don't have Deposit sites permission
				AND s.site <> 'cn88'
				AND ',' + @Permission + ',' NOT LIKE '%,2,%')
			OR (s.site = 'cn88'									-- Don't have CN88 site permission
				AND ',' + @Permission + ',' NOT LIKE '%,3,%'))

	IF NOT EXISTS ( SELECT 1
					FROM dbo.customer AS c WITH (NOLOCK)
						INNER JOIN dbo.customer AS a WITH (NOLOCK) ON c.recommend = a.custid
						WHERE c.custid = @CustId
							AND a.site IN (SELECT Site FROM @DeniedSite))
	BEGIN
		-- bettrans range
		IF @Todate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay
				SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
			ELSE
				SET @TempFromDate = @FromDate

			-- Gold Deluxe, Virtual Games
			IF @ProductId IN (12, 38)
			BEGIN
				IF @GameId <> ''
				BEGIN
					-- translog
					INSERT INTO @Data
					SELECT
						b.gameid AS BetType,
						b.translogid AS TransId,
						0 AS BetId,
						b.translogid AS RefNo,
						'' AS MatchCode,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS OddsType,
						b.status,
						0 AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						CASE
							WHEN s.ProductID = 12 THEN 255
							ELSE b.productID
						END AS SportType,
						b.ip,
						b.betfrom,
						0 AS MatchId,
						(- b.actual_stake) AS WinLost,
						0 AS Commission,
						0 AS SComm,
						0 AS AComm,
						0 AS Comm,
						0 AS AWinLost,
						0 AS MWinLost,
						0 AS SWinLost,
						b.winlostdate,
						b.GameID3rd AS BetCheck,
						CASE
							WHEN s.ProductID = 38 THEN ISNULL(b.transdesc, '')
							ELSE ''
						END AS TransDesc,
						0 AS OddsSpread,
						'' AS ExtraInfo,
						-1 AS BetdaqId
					FROM dbo.translog AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND b.statusID IN (0, 1)
						AND b.Gameid3rd = @GameId
				END

				-- bettrans
				IF @ProductId = 12		-- Gold Deluxe
				BEGIN
					IF @GameId <> '' OR @BetId <> ''
					BEGIN
						INSERT INTO @Data
						SELECT
							b.bettype,
							b.transid,
							ISNULL(b.betid, 0) AS BetId,
							b.refno,
							'' AS MatchCode,
							b.sdiscount,
							b.adiscount,
							b.discount,
							0 AS HomeId,
							0 AS AwayId,
							0 AS Hdp1,
							0 AS Hdp2,
							b.odds,
							0 AS OddsType,
							b.status,
							CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS ComStatus,
							b.stake,
							b.actual_stake,
							b.transdate,
							'' AS BetTeam,
							b.spositiontaking,
							b.mpositiontaking,
							b.apositiontaking,
							0 AS LiveIndicator,
							b.custid,
							0 AS LiveHomeScore,
							0 AS LiveAwayScore,
							0 AS LeagueId,
							255 AS SportType,
							b.ip,
							b.betfrom,
							0 AS MatchId,
							(b.winlost - b.actual_stake) AS WinLost,
							b.playercomm AS Commission,
							(b.scomm - b.acomm) AS SComm,
							(b.acomm - b.comm) AS AComm,
							(b.comm - b.playercomm) AS Comm,
							b.awinlost,
							b.mwinlost,
							b.swinlost,
							b.winlostdate,
							b.betcheck,
							'' AS TransDesc,
							0 AS OddsSpread,
							'' AS ExtraInfo,
							-1 AS BetdaqId
						FROM dbo.bettrans AS b WITH (NOLOCK)
							INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
						WHERE b.custid = @CustId
							AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
							AND b.statusID NOT IN (0, 1)
							AND (@GameId = '' OR b.betcheck = @GameId)
							AND (@BetId = '' OR EXISTS (	SELECT 1 FROM dbo.bettransg AS bg WITH (NOLOCK)
															WHERE bg.refno = b.transid
																AND bg.bettype = b.bettype
																AND bg.BetID3rd =  @BetId ))
					END
				END
				ELSE IF @ProductId = 38		-- Virtual Games
				BEGIN
					IF @GameId <> ''
					BEGIN
						INSERT INTO @Data
						SELECT
							b.bettype,
							b.transid,
							ISNULL(b.betid, 0) AS BetId,
							b.refno,
							'' AS MatchCode,
							b.sdiscount,
							b.adiscount,
							b.discount,
							0 AS HomeId,
							0 AS AwayId,
							0 AS Hdp1,
							0 AS Hdp2,
							b.odds,
							0 AS OddsType,
							b.status,
							CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS ComStatus,
							b.stake,
							b.actual_stake,
							b.transdate,
							'' AS BetTeam,
							b.spositiontaking,
							b.mpositiontaking,
							b.apositiontaking,
							0 AS LiveIndicator,
							b.custid,
							0 AS LiveHomeScore,
							0 AS LiveAwayScore,
							0 AS LeagueId,
							b.matchid AS SportType,
							b.ip,
							b.betfrom,
							0 AS MatchId,
							(b.winlost - b.actual_stake) AS WinLost,
							b.playercomm AS Commission,
							(b.scomm - b.acomm) AS SComm,
							(b.acomm - b.comm) AS AComm,
							(b.comm - b.playercomm) AS Comm,
							b.awinlost,
							b.mwinlost,
							b.swinlost,
							b.winlostdate,
							b.betcheck,
							ISNULL(b.transdesc, '') AS TransDesc,
							0 AS OddsSpread,
							'' AS ExtraInfo,
							-1 AS BetdaqId
						FROM dbo.bettrans AS b WITH (NOLOCK)
							INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
						WHERE b.custid = @CustId
							AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
							AND b.statusID NOT IN (0, 1)
							AND b.betcheck = @GameId
					END
				END
			END

			-- AllBet, SA Gaming, Sexy Gaming, ION
			IF @ProductId IN (21, 39, 45, 46, 52)
			BEGIN
				IF (@GameId <> '' AND @ProductId <> 52)
					OR @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.gameID AS BetType,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.transid, 0)
							ELSE b.transid
						END AS TransId,
						0 AS BetId,
						CASE
							WHEN s.ProductID = 39 THEN b.transid
							ELSE b.refno
						END AS RefNo,
						b.GameId3rd AS MatchCode,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.sdiscount, 0)
							ELSE b.sdiscount
						END AS SDiscount,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.adiscount, 0)
							ELSE b.adiscount
						END AS ADiscount,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.discount, 0)
							ELSE b.discount
						END AS Discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.odds, 0)
							ELSE b.odds
						END AS Odds,
						0 AS OddsType,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.status, '')
							ELSE b.status
						END AS Status,
						'' AS ComStatus,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.stake, 0)
							ELSE b.stake
						END AS Stake,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.stake, 0)
							ELSE b.actual_stake
						END AS Actual_Stake,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.transdate, '')
							ELSE b.transdate
						END AS TransDate,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.BetID3rd, '')
							ELSE ''
						END AS BetTeam,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.spositiontaking, 0)
							ELSE b.spositiontaking
						END AS SPositionTaking,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.mpositiontaking, 0)
							ELSE b.mpositiontaking
						END AS MPositionTaking,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.apositiontaking, 0)
							ELSE b.apositiontaking
						END AS APositionTaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
						b.ip,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.betfrom, '')
							ELSE b.betfrom
						END AS BetFrom,
						0 AS MatchId,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.winlost - bg.stake, 0)
							ELSE b.winlost - b.actual_stake
						END AS WinLost,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.playercomm, 0)
							ELSE b.playercomm
						END AS Commission,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.scomm - bg.acomm, 0)
							ELSE b.scomm - b.acomm
						END AS SComm,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.acomm - bg.comm, 0)
							ELSE b.acomm - b.comm
						END AS AComm,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.comm - bg.playercomm, 0)
							ELSE b.comm - b.playercomm
						END AS Comm,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.awinlost, 0)
							ELSE b.awinlost
						END AS AWinLost,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.mwinlost, 0)
							ELSE b.mwinlost
						END AS MWinLost,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.swinlost, 0)
							ELSE b.swinlost
						END AS SWinLost,
						b.winlostdate,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.TransDesc, '')
							ELSE b.TranId3rd
						END AS BetCheck,
						b.transdesc,
						0 AS OddsSpread,
						'' AS ExtraInfo,
						-1 AS BetdaqId
					FROM dbo.bettransLC AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
						LEFT JOIN dbo.bettransg AS bg WITH (NOLOCK)
							ON bg.refno = b.transid
							AND bg.custid = b.custid
							AND s.ProductID = 39
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND (@GameId = '' OR b.GameId3rd = @GameId)
						AND (@BetId = ''
							OR (s.ProductID IN (21, 45, 46, 52) AND b.TranId3rd = @BetId)
							OR (s.ProductID = 39 AND ISNULL(bg.BetID3rd, '') = @BetId))
				END
			END

			-- Macau Games, Fishing World, Pragmatic Casino, Card Club, Spadegaming, Saba.club, PG Soft, Joker
			IF @ProductId IN (22, 24, 32, 34, 36, 42, 55, 56)
			BEGIN
				IF @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.gameID AS BetType,
						b.transid,
						0 AS BetId,
						b.refno,
						CASE
							WHEN s.productID IN (24, 32, 34, 36) THEN b.Additional
							WHEN s.productID IN (42) THEN ISNULL(b.SiteID, '')
							WHEN s.productID IN (55, 56) THEN ISNULL(b.GameId3rd, '')
							ELSE ''
						END AS MatchCode,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						CASE
							WHEN s.ProductID = 32 AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
							ELSE b.odds
						END AS Odds,
						0 AS OddsType,
						b.status,
						'' AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
						b.ip,
						b.betfrom,
						0 AS MatchId,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS Commission,
						(b.scomm - b.acomm) AS SComm,
						(b.acomm - b.comm) AS AComm,
						(b.comm - b.playercomm) AS Comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						b.winlostdate,
						b.TranId3rd AS BetCheck,
						b.transdesc,
						CASE
							WHEN s.ProductID = 32 AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
							ELSE 0
						END AS OddsSpread,
						CASE
							WHEN s.ProductID = 32 THEN ISNULL(b.JackpotInfo, '')
							ELSE ''
						END AS ExtraInfo,
						CASE
							WHEN s.ProductID = 32 THEN ISNULL(b.RefNo2, -1)
							ELSE -1
						END AS BetdaqId
					FROM dbo.bettransRnG AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND b.TranId3rd = @BetId
				END
			END

			-- BBIN
			IF @ProductId IN (47)
			BEGIN
				IF @GameId <> '' OR @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						bg.bettype,
						bg.transid,
						0 AS BetId,
						bg.refno,
						'' AS MatchCode,
						bg.sdiscount,
						bg.adiscount,
						bg.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						0 AS Odds,
						0 AS OddsType,
						bg.status,
						'' AS ComStatus,
						bg.stake,
						bg.actual_stake,
						bg.transdate,
						ISNULL(bg.betteam, '') AS BetTeam,
						bg.spositiontaking,
						bg.mpositiontaking,
						bg.apositiontaking,
						0 AS LiveIndicator,
						bg.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						bg.matchid AS SportType,
						b.ip,
						bg.betfrom,
						0 AS MatchId,
						bg.winlost - bg.actual_stake AS WinLost,
						bg.playercomm AS Commission,
						bg.scomm - bg.acomm AS SComm,
						bg.acomm - bg.comm AS AComm,
						bg.comm - bg.playercomm AS Comm,
						bg.awinlost,
						bg.mwinlost,
						bg.swinlost,
						bg.winlostdate,
						ISNULL(bg.BetID3rd, '') AS BetCheck,
						bg.transdesc,
						0 AS OddsSpread,
						'' AS ExtraInfo,
						-1 AS BetdaqId
					FROM dbo.bettransg AS bg WITH (NOLOCK)
						INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.transid = bg.refno AND b.custid = bg.custid
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND (@GameId = '' OR bg.betteam = @GameId)
						AND (@BetId = '' OR bg.BetID3rd = @BetId)
				END
			END
		END

		-- bettrans14 range
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			IF @ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET @TempToDate = @ToDate
	
			IF @BalanceUpDay < @FromDate 
				SELECT @BalanceUpDay = @FromDate

			-- Gold Deluxe
			IF @ProductId = 12
			BEGIN
				IF @GameId <> '' OR @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetId,
						b.refno,
						'' AS MatchCode,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS OddsType,
						b.status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						255 AS SportType,
						b.ip,
						b.betfrom,
						0 AS MatchId,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS Commission,
						(b.scomm - b.acomm) AS SComm,
						(b.acomm - b.comm) AS AComm,
						(b.comm - b.playercomm) AS Comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						b.winlostdate,
						b.betcheck,
						'' AS TransDesc,
						0 AS OddsSpread,
						'' AS ExtraInfo,
						-1 AS BetdaqId
					FROM dbo.bettrans14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND b.statusID NOT IN (0, 1)
						AND (@GameId = '' OR b.betcheck = @GameId)
						AND (@BetId = '' OR EXISTS (	SELECT 1 FROM dbo.bettransg14 AS bg WITH (NOLOCK)
														WHERE bg.refno = b.transid
															AND bg.bettype = b.bettype
															AND bg.BetID3rd =  @BetId ))
				END
			END

			-- Virtual Games
			IF @ProductId = 38
			BEGIN
				IF @GameId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetId,
						b.refno,
						'' AS MatchCode,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS OddsType,
						b.status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						b.matchid AS SportType,
						b.ip,
						b.betfrom,
						0 AS MatchId,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS Commission,
						(b.scomm - b.acomm) AS SComm,
						(b.acomm - b.comm) AS AComm,
						(b.comm - b.playercomm) AS Comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						b.winlostdate,
						b.betcheck,
						ISNULL(b.transdesc, '') AS TransDesc,
						0 AS OddsSpread,
						'' AS ExtraInfo,
						-1 AS BetdaqId
					FROM dbo.bettrans14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND b.statusID NOT IN (0, 1)
						AND b.betcheck = @GameId
				END
			END

			-- AllBet, SA Gaming, Sexy Gaming, IBCBet Live Casino, ION
			IF @ProductId IN (21, 39, 45, 46, 52)
			BEGIN
				IF (@GameId <> '' AND @ProductId <> 52)
					OR @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.gameID AS BetType,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.transid, 0)
							ELSE b.transid
						END AS TransId,
						0 AS BetId,
						CASE
							WHEN s.ProductID = 39 THEN b.transid
							ELSE b.refno
						END AS RefNo,
						b.GameId3rd AS MatchCode,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.sdiscount, 0)
							ELSE b.sdiscount
						END AS SDiscount,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.adiscount, 0)
							ELSE b.adiscount
						END AS ADiscount,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.discount, 0)
							ELSE b.discount
						END AS Discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.odds, 0)
							ELSE b.odds
						END AS Odds,
						0 AS OddsType,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.status, '')
							ELSE b.status
						END AS Status,
						'' AS ComStatus,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.stake, 0)
							ELSE b.stake
						END AS Stake,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.stake, 0)
							ELSE b.actual_stake
						END AS Actual_Stake,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.transdate, '')
							ELSE b.transdate
						END AS TransDate,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.BetID3rd, '')
							ELSE ''
						END AS BetTeam,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.spositiontaking, 0)
							ELSE b.spositiontaking
						END AS SPositionTaking,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.mpositiontaking, 0)
							ELSE b.mpositiontaking
						END AS MPositionTaking,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.apositiontaking, 0)
							ELSE b.apositiontaking
						END AS APositionTaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
						b.ip,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.betfrom, '')
							ELSE b.betfrom
						END AS BetFrom,
						0 AS MatchId,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.winlost - bg.stake, 0)
							ELSE b.winlost - b.actual_stake
						END AS WinLost,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.playercomm, 0)
							ELSE b.playercomm
						END AS Commission,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.scomm - bg.acomm, 0)
							ELSE b.scomm - b.acomm
						END AS SComm,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.acomm - bg.comm, 0)
							ELSE b.acomm - b.comm
						END AS AComm,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.comm - bg.playercomm, 0)
							ELSE b.comm - b.playercomm
						END AS Comm,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.awinlost, 0)
							ELSE b.awinlost
						END AS AWinLost,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.mwinlost, 0)
							ELSE b.mwinlost
						END AS MWinLost,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.swinlost, 0)
							ELSE b.swinlost
						END AS SWinLost,
						b.winlostdate,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.TransDesc, '')
							ELSE b.TranId3rd
						END AS BetCheck,
						b.transdesc,
						0 AS OddsSpread,
						'' AS ExtraInfo,
						-1 AS BetdaqId
					FROM dbo.bettransLC14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
						LEFT JOIN dbo.bettransg14 AS bg WITH (NOLOCK)
							ON bg.refno = b.transid
							AND bg.custid = b.custid
							AND s.ProductID = 39
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND (@GameId = '' OR b.GameId3rd = @GameId)
						AND (@BetId = ''
							OR (s.ProductID IN (21, 45, 46, 52) AND b.TranId3rd = @BetId)
							OR (s.ProductID = 39 AND ISNULL(bg.BetID3rd, '') = @BetId))
				END
			END

			-- Macau Games, Fishing World, Pragmatic Casino, Card Club, Spadegaming, Saba.club, PG Soft, Joker
			IF @ProductId IN (22, 24, 32, 34, 36, 42, 55, 56)
			BEGIN
				IF @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.gameID AS BetType,
						b.transid,
						0 AS BetId,
						b.refno,
						CASE
							WHEN s.productID IN (24, 32, 34, 36) THEN b.Additional
							WHEN s.productID IN (42) THEN ISNULL(b.SiteID, '')
							WHEN s.productID IN (55, 56) THEN ISNULL(b.GameId3rd, '')
							ELSE ''
						END AS MatchCode,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						CASE
							WHEN s.ProductID = 32 AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
							ELSE b.odds
						END AS Odds,
						0 AS OddsType,
						b.status,
						'' AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
						b.ip,
						b.betfrom,
						0 AS MatchId,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS Commission,
						(b.scomm - b.acomm) AS SComm,
						(b.acomm - b.comm) AS AComm,
						(b.comm - b.playercomm) AS Comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						b.winlostdate,
						b.TranId3rd AS BetCheck,
						b.transdesc,
						CASE
							WHEN s.ProductID = 32 AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
							ELSE 0
						END AS OddsSpread,
						CASE
							WHEN s.ProductID = 32 THEN ISNULL(b.JackpotInfo, '')
							ELSE ''
						END AS ExtraInfo,
						CASE
							WHEN s.ProductID = 32 THEN ISNULL(b.RefNo2, -1)
							ELSE -1
						END AS BetdaqId
					FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND b.TranId3rd = @BetId
				END
			END

			-- BBIN
			IF @ProductId IN (47)
			BEGIN
				IF @GameId <> '' OR @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						bg.bettype,
						bg.transid,
						0 AS BetId,
						bg.refno,
						'' AS MatchCode,
						bg.sdiscount,
						bg.adiscount,
						bg.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						0 AS Odds,
						0 AS OddsType,
						bg.status,
						'' AS ComStatus,
						bg.stake,
						bg.actual_stake,
						bg.transdate,
						ISNULL(bg.betteam, '') AS BetTeam,
						bg.spositiontaking,
						bg.mpositiontaking,
						bg.apositiontaking,
						0 AS LiveIndicator,
						bg.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						bg.matchid AS SportType,
						b.ip,
						bg.betfrom,
						0 AS MatchId,
						bg.winlost - bg.actual_stake AS WinLost,
						bg.playercomm AS Commission,
						bg.scomm - bg.acomm AS SComm,
						bg.acomm - bg.comm AS AComm,
						bg.comm - bg.playercomm AS Comm,
						bg.awinlost,
						bg.mwinlost,
						bg.swinlost,
						bg.winlostdate,
						ISNULL(bg.BetID3rd, '') AS BetCheck,
						bg.transdesc,
						0 AS OddsSpread,
						'' AS ExtraInfo,
						-1 AS BetdaqId
					FROM dbo.bettransg14 AS bg WITH (NOLOCK)
						INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
						INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK) ON b.transid = bg.refno AND b.custid = bg.custid
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND (@GameId = '' OR bg.betteam = @GameId)
						AND (@BetId = '' OR bg.BetID3rd = @BetId)
				END
			END
		END
	END

	-- Get detail tickets
	IF EXISTS (	SELECT TOP(1) 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype
				WHERE sp.ProductID = 12)
	BEGIN
		IF @Todate > @MoveBetsDay
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
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.BetType
				INNER JOIN @Data AS b ON bg.refno = b.transid AND bg.bettype = b.bettype
			WHERE sp.ProductID = 12
		END

		IF @Fromdate <= @MoveBetsDay
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
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.BetType
				INNER JOIN @Data AS b ON bg.refno = b.transid AND bg.bettype = b.bettype
			WHERE sp.ProductID = 12
		END
	END

	SELECT DISTINCT b.*,
		ci.username,
		ex.currency
	FROM @Data AS b
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON b.CustId = ci.custid
		LEFT JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	ORDER BY b.TransId ASC

	SELECT DISTINCT * FROM @DetailData
END
GO


GRANT EXECUTE ON [dbo].[Acc_BetList_SelByProduct] TO [bodbAdminNet]
GO
