/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Acc_BetList_CashOut_Detail]    Script Date: 3/21/2017 2:46:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Acc_BetList_CashOut_Detail]
	@TransId			BIGINT,
	@RefNo				BIGINT,
	@BetType			SMALLINT,
	@OriginalTransId	BIGINT		= 0
AS

/*
	Created: Kos@20170321
	Task: Get ticket detail of CashOut ticket [#Redmine: 71963]
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @CustId			INT,
		@WinLostDate		SMALLDATETIME,
		@WhTicket			TINYINT,
		@CashOutCustId		INT,
		@CashOutUsername	NVARCHAR(50)

	IF @BetType NOT IN (911, 912)
	BEGIN
		IF @RefNo = 100000000000	-- Bet ticket
		BEGIN
			SET @OriginalTransId = @TransId
		END
		ELSE	-- CashOut bet ticket
		BEGIN
			IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @TransId )
			BEGIN
				SELECT @OriginalTransId = refno
				FROM dbo.bettrans WITH (NOLOCK)
				WHERE transid = @RefNo AND bettype = 911
			END
			ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @TransId )
			BEGIN
				SELECT @OriginalTransId = refno
				FROM dbo.bettrans14 WITH (NOLOCK)
				WHERE transid = @RefNo AND bettype = 911
			END
			ELSE IF EXISTS ( SELECT 1 FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @TransId )
			BEGIN
				SELECT @OriginalTransId = refno
				FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK)
				WHERE transid = @RefNo AND bettype = 911
			END
		END
	END

	-- Create temp table
	DECLARE @Data TABLE (
		BetType			INT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			NVARCHAR(50),
		MatchCode		NVARCHAR(50),
		EventDate		SMALLDATETIME,
		SDiscount		SMALLMONEY,
		ADiscount		SMALLMONEY,
		Discount		SMALLMONEY,
		HomeId			INT,
		AwayId			INT,
		SettleTime		DATETIME,
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
		Modds			MONEY,
		CustId			INT,
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		LeagueId		INT,
		SportType		SMALLINT,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR (1),
		MatchId			INT,
		IsNeutral		BIT,
		WinLost			MONEY,
		Commission		MONEY,
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		ShowTime		NVARCHAR(50),
		WinLostDate		SMALLDATETIME,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		OddsSpread		SMALLMONEY,
		OriginalBetType	INT,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000)
	)

	DECLARE @CashOutData TABLE (
		BetType		INT,
		TransId		BIGINT,
		RefNo		NVARCHAR(50),
		Status		NVARCHAR(50),
		Stake		MONEY,
		TransDate	DATETIME,
		CustId		INT,
		Price		MONEY,
		WinLost		MONEY
	)

	-- Get ticket
	IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @OriginalTransId )
	BEGIN
		SELECT
			@CustId = custid,
			@WinLostDate = winlostdate,
			@WhTicket = 1
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE transid = @OriginalTransId

		INSERT INTO @Data
		SELECT
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0) AS BetId,
			b.refno,
			m.matchcode,
			m.eventdate,
			b.sdiscount,
			b.adiscount,
			b.discount,
			m.homeid,
			m.awayid,
			ISNULL(b.checktime, '') AS SettleTime,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
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
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm AS Commission,
			0 AS SComm,
			0 AS AComm,
			0 AS Comm,
			0 AS AWinLost,
			0 AS MWinLost,
			0 AS SWinLost,
			m.showtime,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			0 AS OriginalBetType,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.transid = @OriginalTransId
	END
	ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @OriginalTransId )
	BEGIN
		SELECT
			@CustId = custid,
			@WinLostDate = winlostdate,
			@WhTicket = 2
		FROM dbo.bettrans14 WITH (NOLOCK)
		WHERE transid = @OriginalTransId

		INSERT INTO @Data
		SELECT
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0) AS BetId,
			b.refno,
			m.matchcode,
			m.eventdate,
			b.sdiscount,
			b.adiscount,
			b.discount,
			m.homeid,
			m.awayid,
			ISNULL(b.checktime, '') AS SettleTime,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
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
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm AS Commission,
			0 AS SComm,
			0 AS AComm,
			0 AS Comm,
			0 AS AWinLost,
			0 AS MWinLost,
			0 AS SWinLost,
			m.showtime,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			0 AS OriginalBetType,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.transid = @OriginalTransId
	END
	ELSE IF EXISTS ( SELECT 1 FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @OriginalTransId )
	BEGIN
		SELECT
			@CustId = custid,
			@WinLostDate = winlostdate,
			@WhTicket = 3
		FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK)
		WHERE transid = @OriginalTransId

		INSERT INTO @Data
		SELECT
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0) AS BetId,
			b.refno,
			m.matchcode,
			m.eventdate,
			b.sdiscount,
			b.adiscount,
			b.discount,
			m.homeid,
			m.awayid,
			ISNULL(b.checktime, '') AS SettleTime,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
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
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm AS Commission,
			0 AS SComm,
			0 AS AComm,
			0 AS Comm,
			0 AS AWinLost,
			0 AS MWinLost,
			0 AS SWinLost,
			m.showtime,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			0 AS OriginalBetType,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.transid = @OriginalTransId
	END

	-- Get CashOut dummy acc custid
	SELECT @CashOutUsername = a.username + 'CashOut'
	FROM dbo.custInfo AS a WITH (NOLOCK)
		INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.recommend = a.custid 
	WHERE c.custid = @CustId

	SELECT @CashOutCustId = custid
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE username = @CashOutUsername

	-- Get CashOut/Bought ticket
	DECLARE @GetCashOutTicket TINYINT = 0

	IF @BetType = 911 OR @RefNo = 100000000000
		SET @GetCashOutTicket = 1

	IF @WhTicket = 1
	BEGIN
		INSERT INTO @CashOutData
		SELECT
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.bettype
				ELSE bb.bettype
			END AS BetType,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.transid
				ELSE bb.transid
			END AS TransId,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.refno
				ELSE bb.refno
			END AS RefNo,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.status
				ELSE bb.status
			END AS Status,
			b.stake,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.transdate
				ELSE bb.transdate
			END AS TransDate,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.custid
				ELSE bb.custid
			END AS CustId,
			bb.actual_stake AS Price,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.winlost - b.actual_stake
				ELSE bb.winlost - bb.actual_stake
			END AS WinLost
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS bb WITH (NOLOCK) ON bb.refno = b.transid
		WHERE b.custid = @CustId
			AND b.winlostdate = @WinLostDate
			AND b.refno = @OriginalTransId
			AND b.bettype = 911
			AND bb.custid = @CashOutCustId
			AND bb.winlostdate = @WinLostDate
			AND bb.bettype = 912
	END
	ELSE IF @WhTicket = 2
	BEGIN
		INSERT INTO @CashOutData
		SELECT
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.bettype
				ELSE bb.bettype
			END AS BetType,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.transid
				ELSE bb.transid
			END AS TransId,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.refno
				ELSE bb.refno
			END AS RefNo,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.status
				ELSE bb.status
			END AS Status,
			b.stake,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.transdate
				ELSE bb.transdate
			END AS TransDate,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.custid
				ELSE bb.custid
			END AS CustId,
			bb.actual_stake AS Price,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.winlost - b.actual_stake
				ELSE bb.winlost - bb.actual_stake
			END AS WinLost
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.bettrans14 AS bb WITH (NOLOCK) ON bb.refno = b.transid
		WHERE b.custid = @CustId
			AND b.winlostdate = @WinLostDate
			AND b.refno = @OriginalTransId
			AND b.bettype = 911
			AND bb.custid = @CashOutCustId
			AND bb.winlostdate = @WinLostDate
			AND bb.bettype = 912
	END
	ELSE IF @WhTicket = 3
	BEGIN
		INSERT INTO @CashOutData
		SELECT
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.bettype
				ELSE bb.bettype
			END AS BetType,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.transid
				ELSE bb.transid
			END AS TransId,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.refno
				ELSE bb.refno
			END AS RefNo,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.status
				ELSE bb.status
			END AS Status,
			b.stake,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.transdate
				ELSE bb.transdate
			END AS TransDate,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.custid
				ELSE bb.custid
			END AS CustId,
			bb.actual_stake AS Price,
			CASE
				WHEN @GetCashOutTicket = 1 THEN b.winlost - b.actual_stake
				ELSE bb.winlost - bb.actual_stake
			END AS WinLost
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN bodb_Archive.dbo.bettrans_bk AS bb WITH (NOLOCK) ON bb.refno = b.transid
		WHERE b.custid = @CustId
			AND b.winlostdate = @WinLostDate
			AND b.refno = @OriginalTransId
			AND b.bettype = 911
			AND bb.custid = @CashOutCustId
			AND bb.winlostdate = @WinLostDate
			AND bb.bettype = 912
	END

	SELECT * FROM @Data
	SELECT * FROM @CashOutData
END



GO
GRANT	VIEW DEFINITION	ON	[Acc_BetList_CashOut_Detail]	TO	vnteam
GRANT	EXECUTE	ON	[Acc_BetList_CashOut_Detail]	TO	bodbExtAccNet
GRANT	EXECUTE	ON	[Acc_BetList_CashOut_Detail]	TO	bodbDownlineNetView
GRANT	EXECUTE	ON	[Acc_BetList_CashOut_Detail]	TO	bodbDownlineNet
GRANT	EXECUTE	ON	[Acc_BetList_CashOut_Detail]	TO	bodbAdminNet
GO
