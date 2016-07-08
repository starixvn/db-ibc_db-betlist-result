USE [bodb02]
GO
/****** Object:  UserDefinedFunction [dbo].[Age_f_SplitString]    Script Date: 5/18/2015 12:03:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  User Defined Function dbo.Age_f_SplitString    Script Date: 5/18/2015 10:22:56 AM ******/
USE bodb02
GO

ALTER FUNCTION  [dbo].[Age_f_SplitString] 
( 
	@string			NVARCHAR( MAX)
	, @splitter		CHAR( 1) 
)
RETURNS @res TABLE 
( 
	Idx				INT
	, Val			NVARCHAR(250) 
)
AS
 /*
	Created	: Bobby.Nguyen
	Task	: Refactor betlist core 
	DB		: DBACC.bodb02
*/
BEGIN
	IF (SUBSTRING ( @string, LEN ( @string), 1)<>@splitter)
	BEGIN
		SET @string = @string + @splitter
	END
	DECLARE @start		INT
		, @word			NVARCHAR(MAX)
		, @charindex	INT
		, @i			INT

	SELECT @i			= 1
		, @start		= 1
		, @charindex	= CHARINDEX( @splitter, @string, @start)

	WHILE (@charindex <> 0)
	BEGIN
		SELECT @word	= SUBSTRING( @string, @start, @charindex - @start)
			, @start	= @charindex +1
			, @charindex= CHARINDEX( @splitter, @string, @start)

		INSERT INTO @res  
		VALUES (@i, @word)

		SET @i = @i+1
	END
	RETURN
END
GO
GRANT SELECT ON [dbo].[Age_f_SplitString] TO [bodbAdminNet]
GO
GRANT SELECT ON [dbo].[Age_f_SplitString] TO [bodbDownlineNet]
GO
GRANT SELECT ON [dbo].[Age_f_SplitString] TO [bodbDownlineNetView] AS [dbo]
GO
