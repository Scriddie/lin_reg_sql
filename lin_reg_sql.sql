drop table if exists features;
drop table if exists labels;
drop table if exists xtx;
drop table if exists xty;
drop table if exists xtx_inverse;


# 1) Create tables; fill with values

create table features (row_num int, col_num int, feature_value int);
insert into features values
    (1, 1, 1),
    (2, 1, 1),
    (3, 1, 1),
    (4, 1, 1),
    (5, 1, 1),
	(1, 2, 1),
    (2, 2, 2),
	(3, 2, 3),
    (4, 2, 4),
    (5, 2, 5),
    (1, 3, 1),
    (2, 3, 4),
	(3, 3, 9),
    (4, 3, 16),
    (5, 3, 25);
    
create table labels (row_num int, col_num int, label_value int);
insert into labels values
    (1, 1, 6),
    (2, 1, 11),
    (3, 1, 20),
    (4, 1, 33),
    (5, 1, 50);


# Calculate X * X

create table XtX (row_num int, col_num int, value int);
insert into XtX
select f1.col_num row_num
     , f2.col_num col_num
     , sum(f1.feature_value * f2.feature_value) value
from features f1
join features f2
on f1.row_num = f2.row_num
group by f1.col_num, f2.col_num;


#Calculate X * Y

create table XtY (row_num int, col_num int, value float);
insert into XtY
select f.col_num row_num
     , l.col_num col_num
     , sum(f.feature_value * l.label_value) value
from features f
join labels l
on f.row_num = l.row_num
group by f.col_num, l.col_num;


# Calculate determinant of X * X

select @determinant := sum(product * product_sign) 
from (
	select (xtx_1.value * xtx_2.value * xtx_3.value) 
	        product
# we need to weight the row_numbers according to the inverse of their natural order
# to estimate degree of permutation
	      , power(-1, dense_rank() over(
         	order by 3 * xtx_1.row_num + 2 * xtx_2.row_num + 1 * xtx_3.row_num) - 1)
         	product_sign
	from XtX xtx_1
	join XtX xtx_2
	  on xtx_1.row_num != xtx_2.row_num
	join XtX xtx_3
	  on xtx_1.row_num != xtx_3.row_num
	 and xtx_2.row_num != xtx_3.row_num
	where xtx_1.col_num = 1
	  and xtx_2.col_num = 2
	  and xtx_3.col_num = 3
	order by 3 * xtx_1.row_num + 2 * xtx_2.row_num + 1 * xtx_1.row_num
) determinant_components;


# Calculate inverse of X * X

create table XtX_inverse (row_num int, col_num int, value float);

insert into XtX_inverse
select mat_pos.col_num as row_num # transponse
     , mat_pos.row_num as col_num 
     , (1 / @determinant) * power(-1, mat_pos.row_num + mat_pos.col_num) * 
     (mat_1.value * mat_4.value - mat_2.value
     * mat_3.value)
     value
  from XtX mat_1
       left join XtX mat_2
            on mat_1.row_num = mat_2.row_num 
            and mat_1.col_num < mat_2.col_num
       left join XtX mat_3
            on mat_3.col_num = mat_1.col_num 
            and mat_3.row_num > mat_1.row_num
       left join XtX mat_4
            on mat_4.col_num = mat_2.col_num 
            and mat_4.row_num > mat_2.row_num
       left join XtX mat_pos
            on mat_pos.row_num not in (mat_1.row_num, mat_4.row_num) 
            and mat_pos.col_num not in (mat_1.col_num, mat_4.col_num) 
where 
    (mat_1.col_num + mat_4.col_num + mat_1.row_num + mat_4.row_num)
    = (mat_2.col_num + mat_3.col_num + mat_2.row_num + mat_3.row_num)
order by mat_pos.row_num, mat_pos.col_num;


# Find coefficients as XtX_inverse * XtY

select round(sum(XtX_inverse.value * XtY.value), 4) coefficients
from XtX_inverse
join XtY
on XtX_inverse.row_num = XtY.row_num
group by XtX_inverse.col_num, XtY.col_num;