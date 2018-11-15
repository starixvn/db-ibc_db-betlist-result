/*<info serverAlias="DBAGE-BODB02" executers="bodbDownlineNet,bodbAdminNet,bodbExtAccNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/

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
	@SiteType		TINYINT			= 0
AS

/*
	Created by: 20160609@Kos
	Task: Search tickets by product
	DB: DBAGE.bodb02
	Original:
	
	Parameter Explanantion
		- @SiteType:
			- 0 : Get all
			- 1 : Exclude deposit sites
			- 2 : Exclude credit sites
	
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
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix --
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID = @ProductId

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
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		OddsSpread		SMALLMONEY,
		ExtraInfo		VARCHAR(1000)
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

	IF @SiteType <> 0
	BEGIN
		INSERT INTO  @DeniedSite (SiteId, Site, SpecialGroup)
		SELECT
			s.siteid,
			s.site,
			s.SpecialGroup
		FROM dbo.Site AS s WITH (NOLOCK)
		WHERE NOT EXISTS (SELECT 1 FROM @DeniedSite WHERE SiteId = s.siteid)
			AND s.isLicensee = CASE
								WHEN @SiteType = 1 THEN 1
								WHEN @SiteType = 2 THEN 0
							END
	END

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

			-- Gold Deluxe
			IF @ProductId = 12
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
						255 AS SportType,
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
						'' AS TransDesc,
						0 AS OddsSpread,
						'' AS ExtraInfo
					FROM dbo.translog AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND b.statusID IN (0, 1)
						AND b.Gameid3rd = @GameId
				END

				IF @GameId <> '' OR @BetId <> ''
				BEGIN
					-- bettrans
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
						'' AS ExtraInfo
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

			-- Poker Games
			IF @ProductId = 33
			BEGIN
				IF @BetId <> ''
				BEGIN
					-- bettrans
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
						b.hdp1,
						0 AS Hdp2,
						0 AS Odds,
						0 AS OddsType,
						b.status,
						ISNULL(b.comstatus, '') AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS LiveIndicator,
						b.custid,
						b.livehomescore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						163 AS SportType,
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
						b.ExtraInfo
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND b.betcheck = @BetId
				END
			END

			-- AllBet
			IF @ProductId = 21
			BEGIN
				IF @GameId <> '' OR @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.gameID AS BetType,
						b.transid,
						0 AS BetId,
						b.refno,
						b.GameId3rd AS MatchCode,
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
						0 AS OddsSpread,
						'' AS ExtraInfo
					FROM dbo.bettransLC AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND (@GameId = '' OR b.GameId3rd = @GameId)
						AND (@BetId = '' OR b.TranId3rd = @BetId)
				END
			END

			-- Bullfighting
			IF @ProductId = 30
			BEGIN
				IF @GameId <> '' OR @BetId <> ''
				BEGIN
					-- translog
					INSERT INTO @Data
					SELECT
						b.gameid AS BetType,
						b.translogid AS TransId,
						0 AS BetId,
						b.translogid AS RefNo,
						m.MatchNo AS MatchCode,
						b.sdiscount,
						b.adiscount,
						b.discount,
						m.HomeId,
						m.AwayId,
						CONVERT(SMALLMONEY, ISNULL(b.custom2, 0)) AS Hdp1,
						0 AS Hdp2,
						b.odds,
						CONVERT(TINYINT, ISNULL(b.custom1, 0)) AS OddsType,
						b.status,
						0 AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						b.custom3 AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						b.liveindicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						m.League3rdId AS LeagueId,
						m.SportType,
						b.ip,
						b.betfrom,
						b.eventid AS MatchId,
						(- b.actual_stake) AS WinLost,
						0 AS Commission,
						0 AS SComm,
						0 AS AComm,
						0 AS Comm,
						0 AS AWinLost,
						0 AS MWinLost,
						0 AS SWinLost,
						b.winlostdate,
						ISNULL(b.Tranid3rd, '') AS BetCheck,
						ISNULL(b.transdesc, '') AS TransDesc,
						0 AS OddsSpread,
						'' AS ExtraInfo
					FROM dbo.translog AS b WITH (NOLOCK)
						INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON b.eventid = m.Match3rdId
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND b.statusID IN (0, 1)
						AND (@GameId = '' OR b.GameId3rd = @GameId)
						AND (@BetId = '' OR b.TranId3rd = @BetId)

					-- bettrans
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetId,
						b.refno,
						m.MatchNo AS MatchCode,
						b.sdiscount,
						b.adiscount,
						b.discount,
						m.HomeId,
						m.AwayId,
						b.hdp1,
						0 AS Hdp2,
						b.odds,
						b.OddsType,
						b.status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						b.betteam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						b.liveindicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						m.League3rdId AS LeagueId,
						m.SportType,
						b.ip,
						b.betfrom,
						b.matchid,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS Commission,
						(b.scomm - b.acomm) AS SComm,
						(b.acomm - b.comm) AS AComm,
						(b.comm - b.playercomm) AS Comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						b.winlostdate,
						ISNULL(b.betcheck, '') AS BetCheck,
						ISNULL(b.transdesc, '') AS TransDesc,
						0 AS OddsSpread,
						'' AS ExtraInfo
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON b.matchid = m.Match3rdId
						INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND b.statusID NOT IN (0, 1)
						AND (@GameId = '' OR CONVERT(VARCHAR(20), b.betid) = @GameId)
						AND (@BetId = '' OR b.betcheck = @BetId)
				END
			END

			-- Macau Games, Fishing World, Pragmatic Casino
			IF @ProductId IN (22, 24, 32)
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
							WHEN s.productID = 24 THEN b.Additional
							ELSE ''
						END AS MatchCode,
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
						0 AS OddsSpread,
						'' AS ExtraInfo
					FROM dbo.bettransRnG AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND b.TranId3rd = @BetId
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
						'' AS ExtraInfo
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

			-- Poker Games
			IF @ProductId = 33
			BEGIN
				IF @BetId <> ''
				BEGIN
					-- bettrans
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
						b.hdp1,
						0 AS Hdp2,
						0 AS Odds,
						0 AS OddsType,
						b.status,
						ISNULL(b.comstatus, '') AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS LiveIndicator,
						b.custid,
						b.livehomescore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						163 AS SportType,
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
						b.ExtraInfo
					FROM dbo.bettrans14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND b.betcheck = @BetId
				END
			END

			-- AllBet
			IF @ProductId = 21
			BEGIN
				IF @GameId <> '' OR @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.gameID AS BetType,
						b.transid,
						0 AS BetId,
						b.refno,
						b.GameId3rd AS MatchCode,
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
						0 AS OddsSpread,
						'' AS ExtraInfo
					FROM dbo.bettransLC14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND (@GameId = '' OR b.GameId3rd = @GameId)
						AND (@BetId = '' OR b.TranId3rd = @BetId)
				END
			END

			-- Bullfighting
			IF @ProductId = 30
			BEGIN
				IF @GameId <> '' OR @BetId <> ''
				BEGIN
					-- bettrans14
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetId,
						b.refno,
						m.MatchNo AS MatchCode,
						b.sdiscount,
						b.adiscount,
						b.discount,
						m.HomeId,
						m.AwayId,
						b.hdp1,
						0 AS Hdp2,
						b.odds,
						b.OddsType,
						b.status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						b.betteam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						b.liveindicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						m.League3rdId AS LeagueId,
						m.SportType,
						b.ip,
						b.betfrom,
						b.matchid,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS Commission,
						(b.scomm - b.acomm) AS SComm,
						(b.acomm - b.comm) AS AComm,
						(b.comm - b.playercomm) AS Comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						b.winlostdate,
						ISNULL(b.betcheck, '') AS BetCheck,
						ISNULL(b.transdesc, '') AS TransDesc,
						0 AS OddsSpread,
						'' AS ExtraInfo
					FROM dbo.bettrans14 AS b WITH (NOLOCK)
						INNER JOIN dbo.Match3rd14 AS m WITH (NOLOCK) ON b.matchid = m.Match3rdId
						INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND (@GameId = '' OR CONVERT(VARCHAR(20), b.betid) = @GameId)
						AND (@BetId = '' OR b.betcheck = @BetId)
				END
			END

			-- Macau Games, Fishing World, Pragmatic Casino
			IF @ProductId IN (22, 24, 32)
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
							WHEN s.productID = 24 THEN b.Additional
							ELSE ''
						END AS MatchCode,
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
						0 AS OddsSpread,
						'' AS ExtraInfo
					FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND b.TranId3rd = @BetId
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
		ci.username
	FROM @Data AS b
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON b.CustId = ci.custid
	ORDER BY b.TransId

	SELECT DISTINCT * FROM @DetailData
END



GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelByProduct] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelByProduct] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelByProduct] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelByProduct] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetList_SelByProduct] TO [vnteam] 
GO
