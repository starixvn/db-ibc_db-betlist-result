USE [bodb_Archive]
GO
/****** Object:  StoredProcedure [dbo].[U3_BetsSelBetList_Old]    Script Date: 5/5/2017 5:26:27 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.U3_BetsSelBetList_Old    Script Date: 1/15/2015 10:22:08 PM ******/
/****** Object:  Stored Procedure dbo.U3_BetsSelBetList_Old    Script Date: 1/14/2015 2:40:24 PM ******/
ALTER PROCEDURE [dbo].[U3_BetsSelBetList_Old]  
	@FromDate datetime,  
	@ToDate datetime,  
	@CustID int,
	@Bettype int = 0
AS  
/*
	Created: 20100123@[Henry]
	Task : Get Bet List from Archive
	DB: DBARC/bodb_archive
	Original: Acc_BetsSelBetList_Old
	Revisions:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Data TABLE (
		bettype				smallint,
		transid				bigint, 
		betid				bigint,
		refno				nvarchar(50), 
		matchcode			nvarchar(50),
		race				nvarchar(20),
		eventdate			smalldatetime,
		virtualrate			float,
		isShowOTExRate		bit,
		sdiscount			smallmoney,
		adiscount			smallmoney,
		discount			smallmoney,
		homeid				int, 
		awayid				int, 
		settleTime			datetime,
		hdp1				smallmoney, 
		hdp2				smallmoney, 
		odds				smallmoney,
		finalodds			smallmoney,
		finalodds2			smallmoney,
		OddsType			tinyint,
		status				nvarchar(50),
		comstatus			nvarchar(50), 
		stake				money,
		actual_stake		money,
		transdate			datetime,
		betteam				nvarchar(10),
		spositiontaking		smallmoney,
		mpositiontaking		smallmoney,
		apositiontaking		smallmoney,
		spositiontaking2	smallmoney,
		mpositiontaking2	smallmoney,
		apositiontaking2	smallmoney,
		liveindicator		bit,
		modds				smallmoney,
		custid				int,
		livehomescore		smallint, 
		liveawayscore		smallint, 
		finalhomescore		smallint, 
		finalawayscore		smallint, 
		leagueid			int, 
		sporttype			smallint, 
		ip					nvarchar(15), 
		betfrom				nvarchar (1),
		matchid				int,
		isNeutral			bit,
		allowdelete			bit,
		winlost				money,
		commission			money,
		scomm				money,	
		acomm				money,
		comm				money,
		awinlost			money,
		mwinlost			money,
		swinlost			money,
		showtime			nvarchar(50),
		winlostdate			smalldatetime	
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

	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductID INT, Bettype INT,EventType INT)
	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4

	IF @Bettype = 0
	BEGIN
		INSERT INTO @Data
		SELECT 
			b.bettype,
			b.transid,
			isnull(b.BetID,0),
			b.refno,
			m.matchcode,
			'' as race,
			m.eventdate as eventdate,
			0,0,
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
			b.status,
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
			b.betfrom,
			b.matchid,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
			0 as allowdelete,
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
			dbo.bettrans_bk as b with (nolock,index=IX_custid) 
			inner join dbo.match_BK as m with (nolock) on b.matchid = m.matchid 
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype
		WHERE	b.winlostdate>= @FromDate and    
				b.winlostdate<= @ToDate and   
				b.custid = @Custid and
				s.ProductID IN(3,4)
		
		INSERT INTO @Data
		SELECT 
			 b.bettype,   
			 b.betid transid,   
			 isnull(b.BetID,0),
			 b.refno,
			 CONVERT(varchar(50), b.refno) as matchcode,   
			 '' as race,
			 '' as eventdate, 
			 0,0,
			 sdiscount,
			 adiscount,
			 discount,	 
			 0 as homeid,   
			 0 as awayid,  
			 '' settleTime, 
			 b.hdp1,
			 b.hdp2,
			 b.odds,   
			 0 finalodds,
			 0 finalodds2,
			 '' OddsType,  
			 b.status,  
			 CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END as comstatus, 
			 b.stake,  
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
			 0 as finalhomescore, 
			 0 as finalawayscore,  
			 0 as leagueid,  
			 252 as sporttype, 
			 b.ip,
			 b.betfrom,
			 b.matchid,
			 CONVERT(BIT,0) as IsNeutral,
			 0 as allowdelete,
			 (b.winlost-b.actual_stake)  winlost,
			 b.playercomm as commission,
 			 (b.scomm - b.acomm) as scomm,
			 (b.acomm - b.comm) as acomm,
			 (b.comm - b.playercomm) as comm,
			 b.awinlost,
			 b.mwinlost,
			 b.swinlost,
			 '' as showtime,
			b.winlostdate								 
		FROM	dbo.bettrans_bk AS b with (nolock, index=IX_custid)	
		INNER JOIN @SportBettype s ON s.Bettype = b.bettype
		WHERE	b.winlostdate>= @FromDate and    
				b.winlostdate<= @ToDate and   
				b.custid = @Custid AND
				s.ProductID = 7
	END
	ELSE --bettype <> 0
	BEGIN
		IF(@bettype IN (SELECT Bettype FROM @SportBettype WHERE ProductID IN(3,4)))
		BEGIN
			INSERT INTO @Data
			SELECT 
				b.bettype,
				b.transid,
				isnull(b.BetID,0),
				b.refno,
				m.matchcode,
				'' as race,
				m.eventdate as eventdate,
				0,0,
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
				b.status,
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
				b.betfrom,
				b.matchid,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				0 as allowdelete,
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
				dbo.bettrans_bk as b with (nolock,index=IX_custid) 
				inner join dbo.match_BK as m with (nolock) on b.matchid = m.matchid 
				INNER JOIN @SportBettype s ON s.Bettype = b.bettype
			WHERE	b.bettype = @bettype AND
					b.winlostdate>= @FromDate AND    
					b.winlostdate<= @ToDate AND   
					b.custid = @Custid AND
					s.ProductID IN(3,4)
		END

		IF(@bettype IN (SELECT Bettype FROM @SportBettype WHERE ProductID = 7))
		BEGIN
			INSERT INTO @Data
			SELECT 
				 b.bettype,   
				 b.betid transid,   
				 isnull(b.BetID,0),
				 b.refno,
				 CONVERT(varchar(50), b.refno) as matchcode,   
				 '' as race,
				 '' as eventdate, 
				 0,0,
				 sdiscount,
				 adiscount,
				 discount,	 
				 0 as homeid,   
				 0 as awayid,  
				 '' settleTime, 
				 b.hdp1,
				 b.hdp2,
				 b.odds,   
				 0 finalodds,
				 0 finalodds2,
				 '' OddsType,  
				 b.status,  
				 CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END as comstatus, 
				 b.stake,  
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
				 0 as finalhomescore, 
				 0 as finalawayscore,  
				 0 as leagueid,  
				 252 as sporttype, 
				 b.ip,
				 b.betfrom,
				 b.matchid,
				 CONVERT(BIT,0) as IsNeutral,
				 0 as allowdelete,
				 (b.winlost-b.actual_stake)  winlost,
				 b.playercomm as commission,
 				 (b.scomm - b.acomm) as scomm,
				 (b.acomm - b.comm) as acomm,
				 (b.comm - b.playercomm) as comm,
				 b.awinlost,
				 b.mwinlost,
				 b.swinlost,
				 '' as showtime,
				b.winlostdate								 
			FROM	dbo.bettrans_bk AS b with (nolock, index=IX_custid)	
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype
			WHERE	b.bettype = @bettype AND
					b.winlostdate>= @FromDate AND    
					b.winlostdate<= @ToDate AND   
					b.custid = @Custid AND
					s.ProductID = 7
		END
	END

	SELECT * 
	FROM @Data
	ORDER BY transid 	

 
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
	FROM dbo.bettransg BG with (NOLOCK)
	INNER JOIN @Data B ON BG.refno = B.refno
	WHERE B.Bettype between 1101 and 1199
		   
		   
	 SELECT * 
	 FROM @DetailData
END


GRANT	EXECUTE	ON	U3_BetsSelBetList_Old	TO	bodbAdminNet
GRANT	VIEW DEFINITION	ON	U3_BetsSelBetList_Old	TO	vnteam
GRANT	EXECUTE	ON	U3_BetsSelBetList_Old	TO	bodbExtAccNet