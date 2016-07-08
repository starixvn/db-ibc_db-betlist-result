ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossHR_MAg]
	@CustID			INT=null, --MasterID
	@Bettype		INT,
	@LeagueId		INT,  
	@Race			VARCHAR(20), 
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@Language		VARCHAR(2) = 'E',
	@MoveBetsDay	SMALLDATETIME
AS

/*
	Created: 
	Task : Betlist
	DB: DB053.bodb02
	Original:
	Revisions:    
		- 20090407@[HanhVu]:- remove refno			
		- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost				
		- 20090505@HiepVo: Change formula of commission
		- 20090530@HiepVo:  Get more data from bettransm for HR
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090710@Phuc: unhide IP for TB currency.
		- 20091024@[MinhNguyen]: get modds, finalodds.
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110512@Johnson: Change column bettype in temporary table from tinyint to SMALLINT
		- 20120927@Sophia: Get comstatus
		- 20130306@Elodie: Add bet list of Virtual HR
		- 20150904@Bobby: Correct master level's custid on betrans14
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @AgWinlossHR TABLE(
		sporttype SMALLINT,
		username NVARCHAR(30),
		bettype SMALLINT,
		transid BIGINT,
		race VARCHAR(20),
		matchcode VARCHAR(30),
		homeID INT,
		awayID INT,
		hdp1 SMALLMONEY,
		hdp2 SMALLMONEY,
		Modds MONEY,
		odds MONEY,
		status NVARCHAR(10),
		stake MONEY,
		winlost MONEY,
		awinlost MONEY,
		mwinlost MONEY,
		swinlost MONEY,
		playercomm MONEY,
		comm MONEY,
		acomm MONEY,
		scomm MONEY,
		transdate DATETIME,
		betteam NVARCHAR(25),
		apositiontaking SMALLMONEY,
		mpositiontaking SMALLMONEY,
		spositiontaking SMALLMONEY,		
		adiscount SMALLMONEY,
		mdiscount SMALLMONEY,
		sdiscount SMALLMONEY,
		liveindicator BIT,
		livehomescore SMALLINT,
		liveawayscore SMALLINT,
		leagueID INT,
		matchid INT, 
		IP VARCHAR(20),
		betstatus VARCHAR(20),
		isNeutral BIT,
		comstatus NVARCHAR(20),
		refno NVARCHAR(50),
		showtime NVARCHAR(50)
	)

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @Bettype IN (1231,1232,1233,1237,1238)	
			INSERT INTO @AgWinlossHR 
			SELECT  
				r.sporttype,  
				b.username,  
				b.bettype,
				b.transid,  
				b.oddsid AS race,  
				o.RacerNum matchcode,  
				o.RacerID homeid,  
				0 awayid,  
				b.hdp1,  
				b.hdp2,  
				modds,
				b.odds,  
				b.status,  
				b.stake,  
				(b.winlost-actual_stake),  
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.playercomm,  
				(b.comm - b.playercomm) AS comm,
				(b.acomm - b.comm) AS acomm ,
				(b.scomm - b.acomm) AS scomm,
				b.transdate,  
				'',  
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking, 
				b.discount,
				b.adiscount,
				b.sdiscount, 
				0,
				b.livehomescore,
				b.liveawayscore,  
				r.leagueID,  
				b.matchid,   
				b.IP AS IP,
				NULL,  
				CONVERT(BIT,0) AS IsNeutral,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.refno,
				r.EventTime AS showtime
			FROM  
				bettrans b WITH (NOLOCK)   
				INNER JOIN VSOutright o WITH (NOLOCK) ON b.oddsid=o.orid   
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE  
				b.MRecommend=@CustID AND  
				b.Winlostdate>=@FromDate AND  
				b.Winlostdate<=@ToDate AND  
				b.matchid = @Race AND  
				b.Bettype= @Bettype AND  
				b.Ruben=1  
		ELSE
			INSERT INTO @AgWinlossHR SELECT
				l.sporttype,
				b.username,
				b.bettype,
				b.transid,
				m.groupmatch AS race,
				m.matchcode,
				m.teamID,
				0,
				b.hdp1,
				b.hdp2,
				modds,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake),
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.playercomm,
				(b.comm - b.playercomm) AS comm,
				(b.acomm - b.comm) AS acomm ,
				(b.scomm - b.acomm) AS scomm,
				b.transdate,
				'',  
				apositiontaking SMALLMONEY,  
				mpositiontaking SMALLMONEY,  
				spositiontaking SMALLMONEY, 
				b.discount,
				b.adiscount,
				b.sdiscount,
				0,
				b.livehomescore,
				b.liveawayscore,   
				l.leagueID,
				b.matchid, 
				b.IP AS IP,
				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				refno,
				'' AS showtime
			FROM
				bettrans b WITH (NOLOCK) 
				INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid	
				INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID		
			WHERE
				b.MRecommend=@CustID AND
				l.leagueid = @LeagueId And  
				m.groupmatch = @Race AND  
				b.Winlostdate>=@FromDate AND
				b.Winlostdate<=@ToDate AND
				b.Bettype= @Bettype AND
				b.Ruben=1
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @Bettype IN (1231,1232,1233,1237,1238)	
			INSERT INTO @AgWinlossHR 
			SELECT  
				r.sporttype,  
				b.username,  
				b.bettype,    	   
				b.transid,  
				b.oddsid AS race,  
				o.RacerNum matchcode,  
				o.RacerID homeid,  
				0 awayid,  
				b.hdp1,  
				b.hdp2,  
				modds,
				b.odds,  
				b.status,  
				b.stake,  
				(b.winlost-actual_stake),  
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.playercomm,  
				(b.comm - b.playercomm) AS comm,
				(b.acomm - b.comm) AS acomm ,
				(b.scomm - b.acomm) AS scomm,
				b.transdate,  
				'',  
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking, 
				b.discount,
				b.adiscount,
				b.sdiscount, 
				0,
				b.livehomescore,
				b.liveawayscore,  
				r.leagueID,  
				b.matchid,   
				b.IP AS IP,
				NULL,  
				CONVERT(BIT,0) AS IsNeutral,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.refno,
				r.EventTime AS showtime
			FROM  
				bettrans14 b WITH (NOLOCK)   
				INNER JOIN VSOutright14 o WITH (NOLOCK) ON b.oddsid=o.orid   
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE  
				b.mRecommend=@CustID AND  
				b.Winlostdate>=@FromDate AND  
				b.Winlostdate<=@ToDate AND  
				b.matchid = @Race AND  
				b.Bettype= @Bettype AND  
				b.Ruben=1  
		ELSE
			INSERT INTO @AgWinlossHR SELECT
				l.sporttype,
				b.username,
				b.bettype,					
				b.transid,
				m.groupmatch AS race,
				m.matchcode,
				m.teamID,
				0,
				b.hdp1,
				b.hdp2,
				modds,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake),
				b.awinlost,
				b.mwinlost,
				b.swinlost,
		
				b.playercomm,
				(b.comm - b.playercomm) AS comm,
				(b.acomm - b.comm) AS acomm ,
				(b.scomm - b.acomm) AS scomm,
		
				b.transdate,
				'',  
				apositiontaking SMALLMONEY,  
				mpositiontaking SMALLMONEY,  
				spositiontaking SMALLMONEY, 
				b.discount,
				b.adiscount,
				b.sdiscount, 
				0,
				b.livehomescore,
				b.liveawayscore,  
				l.leagueID,
				b.matchid, 
				b.IP AS IP,
				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				refno,
				'' AS showtime
			FROM
				bettrans14 b WITH (NOLOCK) 
				INNER JOIN outright14 m WITH (NOLOCK) ON b.matchid=m.orid	
				INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID
			WHERE
				b.MRecommend=@CustID AND
				l.leagueid = @LeagueId And  
				m.groupmatch = @Race AND  
				b.Winlostdate>=@FromDate AND
				b.Winlostdate<=@ToDate AND
				b.Bettype=@Bettype AND
				b.Ruben=1	
	END

	SELECT * FROM @AgWinlossHR ORDER BY Status, Transid

	--get data from bettransm for bettype 33,43
	IF @Bettype = 33 OR @Bettype =43
	BEGIN
		DECLARE @Bettransm TABLE(  
			refno BIGINT,  
			finalodds MONEY,
			odds MONEY,  
			status NVARCHAR(10),  
			apositiontaking SMALLMONEY,  
			mpositiontaking SMALLMONEY,  
			spositiontaking SMALLMONEY,
			bettype SMALLINT
		)   

		IF @Todate > @MoveBetsDay 
		BEGIN
			INSERT INTO @Bettransm
			SELECT 
				BM.refno, 
				BM.finalodds,
				BM.odds, 
				BM.status, 
				BM.apositiontaking, 
				BM.mpositiontaking, 
				BM.spositiontaking,
				BM.bettype  
			FROM bettransm BM with (NOLOCK)
				INNER JOIN @AgWinlossHR B ON BM.refno = B.transid
			WHERE B.Bettype = @Bettype
		END
		
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @Bettransm
			SELECT 
				BM.refno, 
				BM.finalodds,
				BM.odds, 
				BM.status, 
				BM.apositiontaking, 
				BM.mpositiontaking, 
				BM.spositiontaking,
				BM.bettype  
			FROM bettransm14 BM with (NOLOCK)
				INNER JOIN @AgWinlossHR B ON BM.refno = B.transid
			WHERE B.Bettype = @Bettype
		END	
	
		SELECT * FROM @Bettransm ORDER BY RefNo,Bettype
	END

	IF @Bettype = 1233
	BEGIN	  
		IF @Todate > @MoveBetsDay 
		BEGIN
			INSERT INTO @Bettransm
			SELECT 
				BM.refno, 
				BM.finalodds,
				BM.odds, 
				BM.status, 
				BM.apositiontaking, 
				BM.mpositiontaking, 
				BM.spositiontaking,
				BM.bettype  
			FROM bettransm BM with (NOLOCK)
				INNER JOIN @AgWinlossHR B ON BM.refno = B.refno
			WHERE B.Bettype = @Bettype
		END
		
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @Bettransm
			SELECT 
				BM.refno, 
				BM.finalodds,
				BM.odds, 
				BM.status, 
				BM.apositiontaking, 
				BM.mpositiontaking, 
				BM.spositiontaking,
				BM.bettype  
			FROM bettransm14 BM with (NOLOCK)
				INNER JOIN @AgWinlossHR B ON BM.refno = B.refno
			WHERE B.Bettype = @Bettype
		END	
	
		SELECT * FROM @Bettransm ORDER BY RefNo,Bettype
	END
END

GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossHR_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossHR_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossHR_MAg] TO [vnteam]