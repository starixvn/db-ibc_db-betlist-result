
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  User Defined Function dbo.All_f_TransStatus    Script Date: 6/29/2016 9:58:15 AM ******/
/****** Object:  User Defined Function dbo.All_f_TransStatus    Script Date: 5/18/2015 10:22:56 AM ******/
CREATE FUNCTION  [dbo].[All_f_TransStatus] 
( 
	@TransType TINYINT = 0
)
RETURNS @res TABLE ( StatusId	TINYINT, Name VARCHAR(100)  )
AS
 /*
	Created	: Bobby.Nguyen
	Task	: Refactor betlist core 
	DB		: DBEXT.bodb02
*/
BEGIN 
	WITH CteStatus (StatusId, StatusName, TransType)
	AS (
		-- BET TICKET
		SELECT 0, 'Running', 1
		UNION
		SELECT 1, 'Waiting', 1
		UNION
		SELECT 101, 'Reject', 1
		UNION
		SELECT 102, 'Void', 1
		UNION
		SELECT 103, 'Refund', 1
		UNION
		SELECT 111, 'DRAW', 1
		UNION
		SELECT 112, 'WON', 1
		UNION
		SELECT 113, 'LOSE', 1
		-- TRANSFER TICKET
		UNION
		SELECT 121, 'DONE', 2
		UNION
		SELECT 131, 'Completed', 2
		UNION
		SELECT 132, 'Approved', 2
		UNION
		SELECT 141, 'BALANCE', 2
		UNION
		SELECT 142, 'SUM', 2
	)
	INSERT INTO @res ( StatusId, Name )
	SELECT StatusId, StatusName
	FROM CteStatus
	WHERE 1 = CASE	WHEN @TransType > 0 AND TransType = @TransType THEN 1 
					WHEN @TransType = 0 THEN 1 
					ELSE 0 END

	RETURN
END

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT SELECT ON [dbo].[All_f_TransStatus] TO [bodbDownlineNetView]
GO 
 GRANT SELECT ON [dbo].[All_f_TransStatus] TO [bodbDownlineNet]
GO 
 GRANT SELECT ON [dbo].[All_f_TransStatus] TO [bodbAdminNet]
GO 
