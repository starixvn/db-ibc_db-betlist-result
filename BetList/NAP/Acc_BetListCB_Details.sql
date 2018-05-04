/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Acc_BetListCB_Details]
	@RefNo		BIGINT,
	@CustId		INT
AS

/*
	Created by: Kos
	Date: 2015-09-01
	Task: Get details info for Colossus Bet ticket
	DB: DBAGE.bodb02
	Original: 
	
	Revisions:
		- 20151022@Kos: Return more columns to support more detail
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Data TABLE (
		TransId		BIGINT,
		TransDate	DATETIME,
		BetType		INT,
		Sold		SMALLMONEY,
		WinLost		MONEY,
		StatusId	TINYINT,
		Status		NVARCHAR(10),
		SDiscount	SMALLMONEY,
		ADiscount	SMALLMONEY,
		Discount	SMALLMONEY,
		SComm		MONEY,
		AComm		MONEY,
		Comm		MONEY,
		OddsSpread	MONEY
	)

	INSERT INTO @Data
	SELECT transid,
		transdate,
		bettype,
		hdp1 AS Sold,
		(winlost - stake) AS WinLost,
		statusid,
		status,
		sdiscount,
		adiscount,
		discount,
		(scomm - acomm) AS SComm,
		(acomm - comm) AS AComm,
		comm,
		ISNULL(oddsspread, 0) AS OddsSpread
	FROM dbo.bettransm WITH (NOLOCK)
	WHERE refno = @RefNo
		AND custid = @CustId
		AND bettype BETWEEN 18001 AND 18006

	UNION

	SELECT transid,
		transdate,
		bettype,
		hdp1 AS Sold,
		(winlost - stake) AS WinLost,
		statusid,
		status,
		sdiscount,
		adiscount,
		discount,
		(scomm - acomm) AS SComm,
		(acomm - comm) AS AComm,
		comm,
		ISNULL(oddsspread, 0) AS OddsSpread
	FROM dbo.bettransm14 WITH (NOLOCK)
	WHERE refno = @RefNo
		AND bettype BETWEEN 18001 AND 18006
	
	UNION 
	
	SELECT transid,
		transdate,
		bettype,
		hdp1 AS Sold,
		(winlost - stake) AS WinLost,
		statusid,
		status,
		sdiscount,
		adiscount,
		discount,
		(scomm - acomm) AS SComm,
		(acomm - comm) AS AComm,
		comm,
		ISNULL(oddsspread, 0) AS OddsSpread
	FROM DBARC.bodb_archive.dbo.bettransm WITH (NOLOCK)
	WHERE refno = @RefNo
		AND bettype BETWEEN 18001 AND 18006

	SELECT * FROM @Data
END


GO
GRANT EXECUTE ON [dbo].[Acc_BetListCB_Details] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetListCB_Details] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Acc_BetListCB_Details] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetListCB_Details] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetListCB_Details] TO [vnteam] 
GO
