/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[U3_BetList_SelWinLossByBetType]
	@CustId			INT,
	@RoleId			TINYINT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BetType		INT
AS

/*
	Created: 20201228@Kos
	Task: U3 Match Win Loss report bet list by bettype
	DB: DBAGE.bodb02

	Revisions:
		- 20201228@Kos: Created [Redmine: #131371]
		- 20210705@Razor: Show Odds for Happy 5 Linked Games [Redmine: #154704]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211223@Razor: Support Third Party Result API [Redmine: #165815]
*/

BEGIN
	SET NOCOUNT ON;

	-- Check SP Version
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Gather BettypeMatrix
	DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	INSERT INTO @SportBettype
	SELECT ProductID, Bettype, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE BetType = @BetType

	DECLARE @f_date SMALLDATETIME
	DECLARE @t_date SMALLDATETIME

	-- CHECK for MoveBetsDay
	IF @MoveBetsDay IS NULL
	BEGIN
		SELECT @MoveBetsDay = MAX(Winlostdate)
		FROM dbo.bettrans14 WITH (NOLOCK)
	END

	CREATE TABLE #MemBetTicket (
		TransId			BIGINT,
		RefNo			BIGINT,
		CustId			INT,
		Username		NVARCHAR(50),
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetId			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		WinLost			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		PlayerComm		MONEY,
		Comm			MONEY,
		AComm			MONEY,
		SComm			MONEY,
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		TPositionTaking	SMALLMONEY,
		ADiscount		SMALLMONEY,
		MDiscount		SMALLMONEY,
		SDiscount		SMALLMONEY,
		Ip				VARCHAR(45),
		ComStatus		NVARCHAR(20),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		ExtraInfo		VARCHAR(1000),
		Currency		NVARCHAR(50),
		Product			VARCHAR(30),
		CurrencyId		TINYINT,
		SiteId			VARCHAR(20)
	);

	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		TransDesc		VARCHAR(300)
	)

	DECLARE @Tickets TABLE (
		TransId		BIGINT,
		Product		VARCHAR(30)
	)

	IF @ToDate > @MoveBetsDay	-- bettrans
	BEGIN
		SET @f_date = CASE
						WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
						ELSE @FromDate
					END
		SET @t_date = @ToDate

		IF @RoleId = 2
		BEGIN
			INSERT INTO @Tickets (
				TransId,
				Product )
			SELECT
				TransID = b.transid,
				Product = CASE
								WHEN s.ProductID = 3 AND s.EventType = 0 THEN 'H5LG'	-- Number Game - Happy 5 Linked Games
								ELSE 'Unknown'
							END
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.recommend = @CustId
				AND b.winlostdate BETWEEN @f_date AND @t_date
				AND b.statusID > 1
		END

		IF @RoleId = 3
		BEGIN
			INSERT INTO @Tickets (
				TransId,
				Product )
			SELECT
				TransID = b.transid,
				Product = CASE
								WHEN s.ProductID = 3 AND s.EventType = 0 THEN 'H5LG'	-- Number Game - Happy 5 Linked Games
								ELSE 'Unknown'
							END
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.mrecommend = @CustId
				AND b.winlostdate BETWEEN @f_date AND @t_date
				AND b.statusID > 1
		END

		IF @RoleId = 4
		BEGIN
			INSERT INTO @Tickets (
				TransId,
				Product )
			SELECT
				TransID = b.transid,
				Product = CASE
								WHEN s.ProductID = 3 AND s.EventType = 0 THEN 'H5LG'	-- Number Game - Happy 5 Linked Games
								ELSE 'Unknown'
							END
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.srecommend = @CustId
				AND b.winlostdate BETWEEN @f_date AND @t_date
				AND b.statusID > 1
		END

		IF EXISTS (SELECT 1 FROM @Tickets)
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT
				TransId = b.transid,
				RefNo = b.refno,
				CustId = b.custid,
				Username = b.username,
				SportType = CASE
								WHEN c.Product IN ('H5LG') THEN b.matchid
								ELSE 0
							END,
				BetType = b.bettype,
				BetId = ISNULL(b.betid, 0),
				Odds = b.odds,
				Stake = b.stake,
				Actual_Stake = b.actual_stake,
				Status = b.status,
				TransDate = b.transdate,
				WinLostDate = b.winlostdate,
				WinLost = b.winlost - b.actual_stake,
				AWinLost = b.awinLost,
				MWinLost = b.mwinLost,
				SWinLost = b.swinlost,
				PlayerComm = b.playercomm,
				Comm = b.comm - b.playercomm,
				AComm = b.acomm - b.comm,
				SComm = b.scomm - b.acomm,
				APositionTaking = b.apositiontaking,
				MPositionTaking = b.mpositiontaking,
				SPositionTaking = b.spositiontaking,
				TPositionTaking = b.tpositiontaking,
				ADiscount = b.discount,
				MDiscount = b.adiscount,
				SDiscount = b.sdiscount,
				Ip = b.ip,
				ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
				BetCheck = CASE
								WHEN c.Product IN ('H5LG') THEN ISNULL(b.betcheck, '')
								ELSE ''
							END,
				TransDesc = CASE
								WHEN c.Product IN ('H5LG') THEN ISNULL(b.transdesc, '')
								ELSE ''
							END,
				ExtraInfo = '',
				Currency = b.currencyname,
				Product = c.Product,
				CurrencyId = CASE
								WHEN c.Product = 'H5LG' THEN b.currency
								ELSE 0
							END,
				SiteId = CASE
							WHEN c.Product = 'H5LG' THEN CONVERT(VARCHAR(20), b.betdaqid)
							ELSE ''
						END
			FROM @Tickets AS c
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.transid = c.transid
		END
	END
	
	IF @FromDate <= @MoveBetsDay --bettrans14
	BEGIN
		SET @f_date = @FromDate
		SET @t_date = CASE
						WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay
						ELSE @ToDate
					END
		
		DELETE FROM @Tickets

		IF @RoleId = 2
		BEGIN
			INSERT INTO @Tickets (
				TransId,
				Product )
			SELECT
				TransID = b.transid,
				Product = CASE
								WHEN s.ProductID = 3 AND s.EventType = 0 THEN 'H5LG'	-- Number Game - Happy 5 Linked Games
								ELSE 'Unknown'
							END
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.recommend = @CustId
				AND b.winlostdate BETWEEN @f_date AND @t_date
		END

		IF @RoleId = 3
		BEGIN
			INSERT INTO @Tickets (
				TransId,
				Product )
			SELECT
				TransID = b.transid,
				Product = CASE
								WHEN s.ProductID = 3 AND s.EventType = 0 THEN 'H5LG'	-- Number Game - Happy 5 Linked Games
								ELSE 'Unknown'
							END
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.mrecommend = @CustId
				AND b.winlostdate BETWEEN @f_date AND @t_date
		END

		IF @RoleId = 4
		BEGIN
			INSERT INTO @Tickets (
				TransId,
				Product )
			SELECT
				TransID = b.transid,
				Product = CASE
								WHEN s.ProductID = 3 AND s.EventType = 0 THEN 'H5LG'	-- Number Game - Happy 5 Linked Games
								ELSE 'Unknown'
							END
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.srecommend = @CustId
				AND b.winlostdate BETWEEN @f_date AND @t_date
		END

		IF EXISTS (SELECT 1 FROM @Tickets)
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT
				TransId = b.transid,
				RefNo = b.refno,
				CustId = b.custid,
				Username = b.username,
				SportType = CASE
								WHEN c.Product IN ('H5LG') THEN b.matchid
								ELSE 0
							END,
				BetType = b.bettype,
				BetId = ISNULL(b.betid, 0),
				Odds = b.odds,
				Stake = b.stake,
				Actual_Stake = b.actual_stake,
				Status = b.status,
				TransDate = b.transdate,
				WinLostDate = b.winlostdate,
				WinLost = b.winlost - b.actual_stake,
				AWinLost = b.awinLost,
				MWinLost = b.mwinLost,
				SWinLost = b.swinlost,
				PlayerComm = b.playercomm,
				Comm = b.comm - b.playercomm,
				AComm = b.acomm - b.comm,
				SComm = b.scomm - b.acomm,
				APositionTaking = b.apositiontaking,
				MPositionTaking = b.mpositiontaking,
				SPositionTaking = b.spositiontaking,
				TPositionTaking = b.tpositiontaking,
				ADiscount = b.discount,
				MDiscount = b.adiscount,
				SDiscount = b.sdiscount,
				Ip = b.ip,
				ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
				BetCheck = CASE
								WHEN c.Product IN ('H5LG') THEN ISNULL(b.betcheck, '')
								ELSE ''
							END,
				TransDesc = CASE
								WHEN c.Product IN ('H5LG') THEN ISNULL(b.transdesc, '')
								ELSE ''
							END,
				ExtraInfo = '',
				Currency = b.currencyname,
				Product = c.Product,
				CurrencyId = CASE
								WHEN c.Product = 'H5LG' THEN b.currency
								ELSE 0
							END,
				SiteId = CASE
							WHEN c.Product = 'H5LG' THEN CONVERT(VARCHAR(20), b.betdaqid)
							ELSE ''
						END
			FROM @Tickets AS c
				INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK) ON b.transid = c.transid
		END
	END

	SELECT *
	FROM #MemBetTicket
	ORDER BY TransId DESC

	SELECT * 
	FROM @BettransDetail
	ORDER BY RefNo DESC

	DROP TABLE #MemBetTicket
END
GO
