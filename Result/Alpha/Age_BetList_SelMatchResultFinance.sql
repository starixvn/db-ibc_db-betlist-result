ALTER PROCEDURE [dbo].[Age_BetList_SelMatchResultFinance]
	@transid bigint,
	@BalanceUpDay SMALLDATETIME = NULL,	
	@MoveBetsDay SMALLDATETIME = NULL
AS
SET NOCOUNT ON
/*
Created: nqminh@20090407
Task : Select financial result
DB: DBAGE/bodb02
Original: Age_BetList_SelMatchResultFinance
Revisions:
    - 20090407@Nqminh: ----------
    - 20100210@Henry: grant execute for accounting site
    - 20101007@Henry: Change column transid from INT to BIGINT
    - 20130121@Dan: change linked server DB06 to DBARC
*/

Declare @winlostdate smalldatetime 
SELECT @winlostdate = null, @BalanceUpDay = isnull(@BalanceUpDay, current_timestamp), @MoveBetsDay = isnull(@MoveBetsDay, current_timestamp)

SELECT @winlostdate = winlostdate FROM Bettrans (nolock) WHERE transid = @transid 
IF @winlostdate is null
BEGIN
	SELECT @winlostdate = winlostdate FROM Bettrans14 (nolock) WHERE transid = @transid
	IF @winlostdate is null
	BEGIN
		SELECT @winlostdate = winlostdate FROM DBARC.bodb_archive.dbo.Bettrans_BK WITH(NOLOCK) WHERE transid = @transid
	END
END	


--Bettrans
--IF exists(SELECT 1 FROM bettrans WITH(NOLOCK) WHERE transid = @transid)
IF @winlostdate > @MoveBetsDay
BEGIN
	SELECT leagueid, homeid, checktime as [settletime], hdp2 
	FROM bettrans b (nolock)
		 INNER JOIN match m (nolock) ON b.matchid=m.matchid		
	WHERE transid = @transid
	
	RETURN
END
ELSE IF @winlostdate >= @balanceupday and @winlostdate <= @movebetsday
--Bettrans14
--IF exists(SELECT 1 FROM bettrans14 WITH(NOLOCK) WHERE transid = @transid)
BEGIN
	SELECT leagueid, homeid, checktime as [settletime], hdp2 
	FROM bettrans14 b (nolock)
		 INNER JOIN match14 m (nolock) ON b.matchid=m.matchid		
	WHERE transid = @transid
	
	RETURN
END
ELSE 
BEGIN
--DB06.bodb_archive.dbo.bettrans_BK
SELECT leagueid, homeid, checktime as [settletime], hdp2 
FROM DBARC.bodb_archive.dbo.bettrans_BK b (nolock)
	 INNER JOIN DB06.bodb_archive.dbo.Match_BK m (nolock) ON b.matchid=m.matchid		
WHERE transid = @transid
END
	
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultFinance] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultFinance] TO [bodbExtAccNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultFinance] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelMatchResultFinance] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultFinance] TO [bodbAdminNet]
