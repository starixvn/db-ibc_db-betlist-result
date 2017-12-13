USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[U3_BetsSelBetList_ByTransID_Advance]    Script Date: 5/5/2017 5:24:11 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.U3_BetsSelBetList_ByTransID_Advance    Script Date: 1/15/2015 10:22:05 PM ******/
/****** Object:  Stored Procedure dbo.U3_BetsSelBetList_ByTransID_Advance    Script Date: 1/14/2015 2:40:24 PM ******/
ALTER PROCEDURE [dbo].[U3_BetsSelBetList_ByTransID_Advance]
	@TransID bigint
AS  
/*
	Created by: Dom
	Date: 05/01/2015
	Task: Ticket's information by TransID only
	DB: DBAGE/bodb02 
	Original:  [Acc_BetsSelBetList_ByTransID_Advance] 
	
	Revisions:
		
*/ 

BEGIN
SET NOCOUNT ON  


	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductID INT, Bettype INT,EventType INT)
	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4


	DECLARE @refno BIGINT		

	Declare @Data TABLE (
		username		nvarchar(50),
		bettype			int,
		transid			bigint, 
		betid			bigint,
		refno			nvarchar(50), 
		matchcode		nvarchar(50),
		race			nvarchar(20),
		eventdate		smalldatetime,
		virtualrate		float,
		isShowOTExRate	bit,
		sdiscount		smallmoney,
		adiscount		smallmoney,
		discount		smallmoney,
		homeid			int, 
		awayid			int, 
		settleTime		datetime,
		hdp1			smallmoney, 
		hdp2			smallmoney, 
		odds			smallmoney,
		finalodds		smallmoney,
		finalodds2		smallmoney,
		OddsType		tinyint,
		status			nvarchar(50), 
		comstatus		nvarchar(50),
		stake			money,
		actual_stake	money,
		transdate		datetime,
		betteam			nvarchar(10),
		spositiontaking smallmoney,
		mpositiontaking smallmoney,
		apositiontaking smallmoney,
		spositiontaking2 smallmoney,
		mpositiontaking2 smallmoney,
		apositiontaking2 smallmoney,
		liveindicator	 bit,
		modds			smallmoney,
		custid			int,
		livehomescore	int, 
		liveawayscore	int, 
		finalhomescore	int, 
		finalawayscore	int, 
		leagueid		int, 
		sporttype		smallint, 
		ip				nvarchar(15), 
		betFROM			nvarchar (1),
		matchid			int,
		isNeutral		bit,
		winlost			money,
		commission		money,
		scomm			money,	
		acomm			money,
		comm			money,
		awinlost		money,
		mwinlost		money,
		swinlost		money,
		showtime		nvarchar(50),
		winlostdate		smalldatetime
	)

	DECLARE @DetailData TABLE (
		refno			nvarchar(50), 
		odds			smallmoney, 
		stake			money,
		status			nvarchar(50),
		apositiontaking smallmoney, 
		mpositiontaking smallmoney, 
		spositiontaking smallmoney,
		bettype			smallint,
		betteam			nvarchar(50)
	)

	DECLARE @WinlostDate smalldatetime, @MoveBetsDay smalldatetime, @BalanceUpDay smalldatetime, @bettype int
	DECLARE @tmp TABLE (BalanceUpDay smalldatetime, MoveBetsDay smalldatetime) 
	INSERT INTO @tmp(BalanceUpDay, MoveBetsDay)
	EXEC Age_SelBalanceUpDay

	SELECT @MoveBetsDay = MoveBetsDay, @BalanceUpDay = BalanceUpDay FROM @tmp

	IF exists (SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @TransID)
		SELECT @WinlostDate = winlostdate, @bettype = bettype FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @TransID
	ELSE IF exists(SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @TransID)
		SELECT @WinlostDate = winlostdate, @bettype = bettype FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @TransID
	ELSE 
		SELECT @WinlostDate = winlostdate, @bettype = bettype FROM DBARC.bodb_archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @TransID

	--Bettrans
	IF @WinlostDate > @MoveBetsDay
	BEGIN
		IF EXISTS(SELECT * FROM @SportBettype WHERE ProductID IN(3,4) AND bettype = @bettype)--LS and NumberGame
		BEGIN
			INSERT INTO @Data
			SELECT 
				b.username,
				b.bettype,
				b.transid,
				isnull(b.BetID,0) as BetID,
				b.refno,
				m.matchcode,
				'' as race,
				m.eventdate as eventdate,
				0 as virtualrate,
				0 as isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,	
				m.homeid,
				m.awayid,
				ISNULL(b.checktime,'') settleTime,
				b.hdp1,
				b.hdp2,
				b.odds,   
				0 finalodds,
				0 finalodds2,
				b.OddsType,  
				CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					 ELSE b.status 
					 END as status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END as comstatus,
				stake,
				b.actual_stake,
				b.transdate,
				b.betteam, 
				b.spositiontaking,   
				b.mpositiontaking,   
				b.apositiontaking,
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,   
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
				b.betFROM,
				b.matchid,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm as commission,
				(b.scomm - b.acomm) as scomm,
				(b.acomm - b.comm) as acomm,
				(b.comm - b.playercomm) as comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				m.showtime,
				b.winlostdate	
			FROM 
				dbo.bettrans as b WITH (NOLOCK) 
				INNER JOIN dbo.match as m WITH (NOLOCK) on b.matchid = m.matchid --phuong.nguyen, remove left join match_remark
			WHERE b.transid = @TransID
		END
	END

	--Bettrans14
	ELSE IF @WinlostDate <= @MoveBetsDay and @WinlostDate >= @BalanceUpDay
	BEGIN
		IF EXISTS(SELECT * FROM @SportBettype WHERE ProductID IN(3,4) AND bettype = @bettype)--LS and NumberGame
		BEGIN
			INSERT INTO @Data
			SELECT 
				b.username,
				b.bettype,
				b.transid,
				isnull(b.BetID,0) as BetID,
				b.refno,
				m.matchcode,
				'' as race,
				m.eventdate as eventdate,
				0 as virtualrate,
				0 as isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,	
				m.homeid,
				m.awayid,
				ISNULL(b.checktime,'') settleTime,
				b.hdp1,
				b.hdp2,
				b.odds,   
				0 finalodds,
				0 finalodds2,
				b.OddsType,  
				CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					 ELSE b.status 
					 END as status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END as comstatus,
				stake,
				b.actual_stake,
				b.transdate,
				b.betteam, 
				b.spositiontaking,   
				b.mpositiontaking,   
				b.apositiontaking,
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,   
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
				b.betFROM,
				b.matchid,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm as commission,
				(b.scomm - b.acomm) as scomm,
				(b.acomm - b.comm) as acomm,
				(b.comm - b.playercomm) as comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				m.showtime,
				b.winlostdate	
			FROM 
				dbo.bettrans14 as b WITH (NOLOCK) 
				INNER JOIN dbo.match14 as m WITH (NOLOCK) on b.matchid = m.matchid --phuong.nguyen, remove left join match_remark
			WHERE b.transid = @TransID
		END
	END

	ELSE IF @WinlostDate < @BalanceUpDay
	BEGIN
		IF EXISTS(SELECT * FROM @SportBettype WHERE ProductID IN(3,4) AND bettype = @bettype)--LS and NumberGame
		BEGIN
			INSERT INTO @Data
			SELECT 
				c.username,
				b.bettype,
				b.transid,
				isnull(b.BetID,0) as BetID,
				b.refno,
				m.matchcode,
				'' as race,
				m.eventdate as eventdate,
				0 as virtualrate,
				0 as isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,	
				m.homeid,
				m.awayid,
				ISNULL(b.checktime,'') settleTime,
				b.hdp1,
				b.hdp2,
				b.odds,   
				0 finalodds,
				0 finalodds2,
				b.OddsType,  
				CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					 ELSE b.status 
					 END as status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END as comstatus,
				stake,
				b.actual_stake,
				b.transdate,
				b.betteam, 
				b.spositiontaking,   
				b.mpositiontaking,   
				b.apositiontaking,
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,   
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
				b.betFROM,
				b.matchid,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm as commission,
				(b.scomm - b.acomm) as scomm,
				(b.acomm - b.comm) as acomm,
				(b.comm - b.playercomm) as comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				m.showtime,
				b.winlostdate	
			FROM 
				DBARC.bodb_archive.dbo.bettrans_bk as b WITH (NOLOCK) 
				INNER JOIN DBARC.bodb_archive.dbo.match_BK as m WITH (NOLOCK) on b.matchid = m.matchid --phuong.nguyen, remove left join match_remark
				INNER JOIN custInfo c WITH (NOLOCK) on c.custid = b.custid
			WHERE b.transid = @TransID
		END
	END

	
	SELECT * 
	FROM @Data
	ORDER BY transid  

	IF @bettype between 1101 and 1199 
	BEGIN
		INSERT INTO @DetailData
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,
			BG.status,
			BG.apositiontaking, 
			BG.mpositiontaking, 
			BG.spositiontaking,
			BG.bettype,
			BG.betteam  
		FROM dbo.bettransg BG WITH (NOLOCK)
		INNER JOIN @Data B ON BG.refno = B.refno
		WHERE B.Bettype between 1101 and 1199
		   
		INSERT INTO @DetailData
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,
			BG.status,
			BG.apositiontaking, 
			BG.mpositiontaking, 
			BG.spositiontaking,
			BG.bettype,
			BG.betteam  
		FROM dbo.bettransg14 BG WITH (NOLOCK)
		INNER JOIN @Data B ON BG.refno = B.refno
		WHERE B.Bettype between 1101 and 1199
		
		INSERT INTO @DetailData
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,
			BG.status,
			BG.apositiontaking, 
			BG.mpositiontaking, 
			BG.spositiontaking,
			BG.bettype,
			BG.betteam  
		FROM DBARC.bodb_archive.dbo.bettransg BG WITH (NOLOCK)
		INNER JOIN @Data B ON BG.refno = B.refno
		WHERE B.Bettype between 1101 and 1199
	END
		   
	SELECT * 
	FROM @DetailData
END

GO
GRANT	EXECUTE	ON	U3_BetsSelBetList_ByTransID_Advance	TO	bodbAdminNet
GRANT	VIEW DEFINITION	ON	U3_BetsSelBetList_ByTransID_Advance	TO	vnteam
GRANT	EXECUTE	ON	U3_BetsSelBetList_ByTransID_Advance	TO	bodbExtAccNet
GO
