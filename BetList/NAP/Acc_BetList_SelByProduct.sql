USE [bodb02]
GO

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
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created by: 20160609@Kos
	Task: Search tickets by product
	DB: DBAGE.bodb02
	Original:
	
	Revisions:
		- 20160623@Kos: Hide special sites from unauthorized users [#Redmine: 48948]
		- 20160906@Kos: Support AllBet [#Redmine: 61876]
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

	DELETE FROM @SportBettype
	WHERE ProductID <> @ProductId

	-- Get CustId if @CustId IS NULL
	IF @CustId IS NULL OR @CustId = 0
	BEGIN
		SELECT @CustId = custid
		FROM dbo.custInfo WITH (NOLOCK)
		WHERE username = @Username
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
		TransDesc			NVARCHAR(300),
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

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	DECLARE @DeniedSite TABLE (
		SiteId			INT,
		Site			NVARCHAR(50),
		SpecialGroup	TINYINT)

	DECLARE @Sql VARCHAR(500)

	SET @Sql = 'SELECT * 
				FROM OPENQUERY(DBPOLICY,
					''SELECT siteid, site, SpecialGroup
					FROM bodb02.dbo.f_GetDeniedSiteByUser( ''''' + CAST(@UserId AS VARCHAR(50)) + ''''')'')'

	INSERT INTO @DeniedSite
	EXEC (@Sql)

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
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS FinalOdds,
						0 AS FinalOdds2,
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
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS LiveIndicator,
						0 AS Modds,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS FinalHomeScore,
						0 AS FinalAwayScore,
						0 AS LeagueId,
						255 AS SportType,
						b.ip,
						b.betfrom,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						(- b.actual_stake) AS WinLost,
						0 AS Commission,
						0 AS SComm,
						0 AS AComm,
						0 AS Comm,
						0 AS AWinLost,
						0 AS MWinLost,
						0 AS SWinLost,
						'' AS ShowTime,
						b.winlostdate,
						b.GameID3rd AS BetCheck,
						'' AS TransDesc,
						0 AS OddsSpread
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
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS FinalOdds,
						0 AS FinalOdds2,
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
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS LiveIndicator,
						0 AS Modds,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS FinalHomeScore,
						0 AS FinalAwayScore,
						0 AS LeagueId,
						255 AS SportType,
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
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS FinalOdds,
						0 AS FinalOdds2,
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
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS LiveIndicator,
						0 AS Modds,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS FinalHomeScore,
						0 AS FinalAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
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
						b.TranId3rd AS BetCheck,
						b.transdesc,
						0 AS OddsSpread
					FROM dbo.bettransLC AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND (@GameId = '' OR b.GameId3rd = @GameId)
						AND (@BetId = '' OR b.TranId3rd = @BetId)
				END
			END

			-- Macau Games
			IF @ProductId = 22
			BEGIN
				IF @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.gameID AS BetType,
						b.transid,
						0 AS BetId,
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
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS FinalOdds,
						0 AS FinalOdds2,
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
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS LiveIndicator,
						0 AS Modds,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS FinalHomeScore,
						0 AS FinalAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
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
						b.TranId3rd AS BetCheck,
						b.transdesc,
						0 AS OddsSpread
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
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS FinalOdds,
						0 AS FinalOdds2,
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
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS LiveIndicator,
						0 AS Modds,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS FinalHomeScore,
						0 AS FinalAwayScore,
						0 AS LeagueId,
						255 AS SportType,
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
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS FinalOdds,
						0 AS FinalOdds2,
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
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS LiveIndicator,
						0 AS Modds,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS FinalHomeScore,
						0 AS FinalAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
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
						b.TranId3rd AS BetCheck,
						b.transdesc,
						0 AS OddsSpread
					FROM dbo.bettransLC14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND (@GameId = '' OR b.GameId3rd = @GameId)
						AND (@BetId = '' OR b.TranId3rd = @BetId)
				END
			END

			-- Macau Games
			IF @ProductId = 22
			BEGIN
				IF @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.gameID AS BetType,
						b.transid,
						0 AS BetId,
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
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS FinalOdds,
						0 AS FinalOdds2,
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
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS LiveIndicator,
						0 AS Modds,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS FinalHomeScore,
						0 AS FinalAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
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
						b.TranId3rd AS BetCheck,
						b.transdesc,
						0 AS OddsSpread
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
	IF EXISTS (	SELECT TOP 1 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype
				WHERE ProductID = 12)
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

	SELECT b.*,
		ci.username
	FROM @Data AS b
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON b.CustId = ci.custid
	ORDER BY b.TransId

	SELECT * FROM @DetailData
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
